package com.myapplication.common.data

import com.myapplication.common.domain.getDateString
import io.ktor.client.HttpClient
import kotlinx.datetime.LocalDate
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.seconds

/**
 * Rails の GraphQL を真実の源とする実装。
 *
 * 集計は一切しない。getHome / getProgress / getWorkoutSession は
 * サーバが組み立てたものをそのまま画面へ渡す。
 * ここに計算が生えたら、それはサーバへ移すべきロジックが漏れている合図。
 *
 * 例外はワークアウト記録で、圏外のときだけ手元で暫定のサマリーを作る。
 * サーバの応答を待たないと結果画面が出せない、という状態を避けるため。
 */
class ServerRepository(
    val db: LocalDb,
    /** 端末シードと、未登録のあいだの読み書きを担う。捨てない */
    val local: Repository,
    endpoint: String,
    httpClient: HttpClient,
    timeZoneName: () -> String = { "Asia/Tokyo" },
) : NikkakeRepository {

    val queue = OfflineQueue(db)
    private val client = GraphQLClient(endpoint, { db.getMeta().apiToken }, httpClient, timeZoneName)

    private var withStarterRoutine = true

    val token: String? get() = db.getMeta().apiToken
    val hasSession: Boolean get() = token != null

    /**
     * 初期ルーティンをサーバに作らせない。
     * 端末側でシードしてから預けるので、両方で作ると2つ並ぶ。
     */
    fun suppressStarterRoutine() {
        withStarterRoutine = false
    }

    // ==============================
    // 遅延登録
    // ==============================

    override suspend fun seedIfNeeded(): Boolean = local.seedIfNeededLocal()

    /**
     * 匿名アカウントを作る。圏外なら null を返すだけで、例外にしない。
     * ここで投げるとアプリを入れた直後に圏外だと1歩も動かなくなる。
     */
    suspend fun ensureSession(): String? {
        token?.let { return it }

        return try {
            val data = client.request(
                Operations.CREATE_ANONYMOUS_ACCOUNT,
                buildJsonObject {
                    put("timeZone", client.timeZoneName())
                    put("withStarterRoutine", withStarterRoutine)
                },
            )
            val issued = data["createAnonymousAccount"]?.jsonObject?.get("token")?.str()
            if (issued != null) db.setMeta(apiToken = issued)
            issued
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 端末のデータをまるごとサーバへ預ける。
     *
     * 起動のたびに送ってはいけない。以降の書き込みはサーバが正になるので、
     * 繰り返すとサーバ側で消したルーティンが端末のコピーから復活する。
     * force は「切り替え直前に書かれたぶんを拾う」ためだけに使う。
     */
    suspend fun importSnapshot(force: Boolean = false): Boolean {
        if (db.getMeta().snapshotImportedAt != null && !force) return false

        // プリセット種目はサーバが持っている。送ると is_preset を上書きしてしまう
        val exercises = db.readRaw(Collections.EXERCISES, Exercise.serializer()).filter { !it.isPreset }
        val routines = db.readRaw(Collections.ROUTINES, Routine.serializer())
        val routineExercises = db.readRaw(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer())
        val routineLogs = db.readRaw(Collections.ROUTINE_LOGS, RoutineLog.serializer())
        val exerciseLogs = db.readRaw(Collections.EXERCISE_LOGS, ExerciseLog.serializer())

        val data = client.request(
            Operations.IMPORT_SNAPSHOT,
            buildJsonObject {
                put("exercises", jsonListOf(exercises, Exercise.serializer()))
                put("routines", jsonListOf(routines, Routine.serializer()))
                put("routineExercises", jsonListOf(routineExercises, RoutineExercise.serializer()))
                put("routineLogs", jsonListOf(routineLogs, RoutineLog.serializer()))
                put("exerciseLogs", jsonListOf(exerciseLogs, ExerciseLog.serializer()))
            },
        )

        val errors = data["importSnapshot"]?.jsonObject?.get("userErrors")?.jsonArray
        if (!errors.isNullOrEmpty()) return false

        db.setMeta(snapshotImportedAt = com.myapplication.common.domain.nowIso())
        return true
    }

    /** 圏外中に溜まった記録を送る */
    suspend fun flushQueue(): Int = queue.flush { op -> client.request(Operations.RECORD_WORKOUT, op.payload) }

    // ==============================
    // サーバ表現 → 端末表現
    // ==============================

    private fun exerciseFromJson(e: JsonObject): Exercise {
        val now = com.myapplication.common.domain.nowIso()
        return Exercise(
            id = e["id"].str()!!,
            name = e["name"].str()!!,
            category = (e["category"].str() ?: ExerciseCategory.STRENGTH).lowercase(),
            icon = e["icon"].str(),
            isPreset = e["isPreset"].bool() ?: false,
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun routineFromJson(r: JsonObject): RoutineWithExercises {
        val now = com.myapplication.common.domain.nowIso()
        val routine = Routine(
            id = r["id"].str()!!,
            name = r["name"].str()!!,
            description = r["description"].str(),
            color = r["color"].str() ?: "#6C5CE7",
            icon = r["icon"].str() ?: "💪",
            frequencyType = (r["frequencyType"].str() ?: FrequencyType.DAILY).lowercase(),
            frequencyValue = r["frequencyValue"].int() ?: 1,
            frequencyDays = (r["frequencyDays"]?.jsonArray ?: JsonArray(emptyList())).mapNotNull { it.int() },
            isActive = r["isActive"].bool() ?: true,
            sortOrder = r["sortOrder"].int() ?: 0,
            createdAt = now,
            updatedAt = now,
        )

        val links = (r["routineExercises"]?.jsonArray ?: JsonArray(emptyList())).map { raw ->
            val l = raw.jsonObject
            val exercise = exerciseFromJson(l["exercise"]!!.jsonObject)
            RoutineExerciseWithExercise(
                link = RoutineExercise(
                    id = l["id"].str()!!,
                    routineId = routine.id,
                    exerciseId = exercise.id,
                    sortOrder = l["sortOrder"].int() ?: 0,
                    targetSets = l["targetSets"].int() ?: 3,
                    targetReps = l["targetReps"].int(),
                    targetWeight = l["targetWeight"].dbl(),
                    targetDurationSec = l["targetDurationSec"].int(),
                    restSec = l["restSec"].int(),
                    createdAt = now,
                    updatedAt = now,
                ),
                exercise = exercise,
            )
        }

        return RoutineWithExercises(routine = routine, exercises = links)
    }

    private fun todayRoutineFromJson(t: JsonObject) = TodayRoutine(
        routine = routineFromJson(t["routine"]!!.jsonObject),
        isDueToday = t["isDueToday"].bool() ?: false,
        isCompleted = t["isCompleted"].bool() ?: false,
        frequencyLabel = t["frequencyLabel"].str() ?: "",
    )

    private fun streakFromJson(s: JsonObject?) = StreakInfo(
        current = s?.get("current").int() ?: 0,
        longest = s?.get("longest").int() ?: 0,
        lastCompletedDate = s?.get("lastCompletedDate").str(),
    )

    /** 楽観ロック用。サーバが返した版を覚えておく */
    private val lockVersions = mutableMapOf<String, Int>()

    private fun remember(r: JsonObject): JsonObject {
        lockVersions[r["id"].str()!!] = r["lockVersion"].int() ?: 0
        return r
    }

    // ==============================
    // 参照
    // ==============================

    override suspend fun getHome(todayDate: LocalDate?): HomeView {
        val date = todayDate ?: com.myapplication.common.domain.today()
        val data = client.request(
            Operations.HOME,
            buildJsonObject {
                // 「今日」は必ず端末が決める。サーバに求めさせるとTZで1日ずれる
                put("today", getDateString(date))
                put("timeZone", client.timeZoneName())
            },
        )

        val view = data["home"]!!.jsonObject
        fun group(key: String) = (view[key]?.jsonArray ?: JsonArray(emptyList()))
            .map { todayRoutineFromJson(it.jsonObject) }

        return HomeView(
            today = view["today"].str() ?: getDateString(date),
            streak = streakFromJson(view["streak"]?.jsonObject),
            due = group("due"),
            notScheduled = group("notScheduled"),
            completed = group("completed"),
        )
    }

    override suspend fun getProgress(rangeDays: Int, todayDate: LocalDate?): ProgressView {
        val date = todayDate ?: com.myapplication.common.domain.today()
        val data = client.request(
            Operations.PROGRESS,
            buildJsonObject {
                put("today", getDateString(date))
                put("timeZone", client.timeZoneName())
                put("rangeDays", rangeDays)
            },
        )

        val view = data["progress"]!!.jsonObject
        val overall = view["overall"]?.jsonObject

        return ProgressView(
            overall = OverallStats(
                totalWorkouts = overall?.get("totalWorkouts").int() ?: 0,
                thisWeekCount = overall?.get("thisWeekCount").int() ?: 0,
                totalDurationSec = overall?.get("totalDurationSec").int() ?: 0,
                totalSets = overall?.get("totalSets").int() ?: 0,
            ),
            streak = streakFromJson(view["streak"]?.jsonObject),
            dailyStats = (view["dailyStats"]?.jsonArray ?: JsonArray(emptyList())).map {
                val d = it.jsonObject
                DailyStats(
                    date = d["date"].str()!!,
                    completedCount = d["completedCount"].int() ?: 0,
                    totalCount = d["totalCount"].int() ?: 0,
                )
            },
            completedDates = (view["completedDates"]?.jsonArray ?: JsonArray(emptyList()))
                .mapNotNull { it.str() }.toSet(),
            exercisesWithLogs = (view["exercisesWithLogs"]?.jsonArray ?: JsonArray(emptyList()))
                .map { exerciseFromJson(it.jsonObject) },
        )
    }

    override suspend fun getExerciseProgressPoints(exerciseId: String, limit: Int): List<ExerciseProgressPoint> {
        val data = client.request(
            Operations.EXERCISE_PROGRESS,
            buildJsonObject {
                put("exerciseId", exerciseId)
                put("limit", limit)
            },
        )

        return (data["exerciseProgress"]?.jsonArray ?: JsonArray(emptyList())).map {
            val p = it.jsonObject
            ExerciseProgressPoint(
                date = p["date"].str()!!,
                maxWeight = p["maxWeight"].dbl() ?: 0.0,
                totalReps = p["totalReps"].int() ?: 0,
                totalVolume = p["totalVolume"].dbl() ?: 0.0,
            )
        }
    }

    override suspend fun getDay(date: String): DayView {
        val data = client.request(
            Operations.DAY,
            buildJsonObject {
                put("date", date)
                put("timeZone", client.timeZoneName())
            },
        )

        val view = data["day"]!!.jsonObject

        return DayView(
            date = view["date"].str() ?: date,
            workouts = (view["workouts"]?.jsonArray ?: JsonArray(emptyList())).map {
                val w = it.jsonObject
                DayWorkout(
                    routineLogId = w["routineLogId"].str()!!,
                    routineName = w["routineName"].str() ?: "",
                    status = (w["status"].str() ?: LogStatus.SKIPPED).lowercase(),
                    durationSec = w["durationSec"].int(),
                    exercises = (w["exercises"]?.jsonArray ?: JsonArray(emptyList())).map { e ->
                        val ex = e.jsonObject
                        DayExerciseSummary(
                            exerciseName = ex["exerciseName"].str() ?: "",
                            setsLabel = ex["setsLabel"].str(),
                        )
                    },
                )
            },
        )
    }

    override suspend fun getWorkoutSession(routineId: String): WorkoutSessionView? {
        val data = client.request(Operations.WORKOUT_SESSION, buildJsonObject { put("routineId", routineId) })
        val session = data["workoutSession"]?.jsonObject ?: return null
        val routineJson = remember(session["routine"]!!.jsonObject)

        val exercises = (session["exercises"]?.jsonArray ?: JsonArray(emptyList())).map { raw ->
            val e = raw.jsonObject
            val previousSets = (e["previousSets"]?.jsonArray ?: JsonArray(emptyList())).map { raw2 ->
                val s = raw2.jsonObject
                WorkoutSet(
                    setNumber = s["setNumber"].int()!!,
                    reps = s["reps"].int(),
                    weight = s["weight"].dbl(),
                    durationSec = s["durationSec"].int(),
                    completed = true,
                )
            }

            WorkoutSessionEntry(
                routineExerciseId = e["routineExerciseId"].str()!!,
                exercise = exerciseFromJson(e["exercise"]!!.jsonObject),
                targetSets = e["targetSets"].int() ?: 3,
                targetReps = e["targetReps"].int(),
                targetWeight = e["targetWeight"].dbl(),
                targetDurationSec = e["targetDurationSec"].int(),
                restSec = e["restSec"].int() ?: 60,
                previousSets = previousSets,
                previousLabel = e["previousLabel"].str(),
            )
        }

        return WorkoutSessionView(routine = routineFromJson(routineJson), exercises = exercises)
    }

    override suspend fun listExercises(): List<Exercise> {
        val data = client.request(Operations.EXERCISES)
        return (data["exercises"]?.jsonArray ?: JsonArray(emptyList())).map { exerciseFromJson(it.jsonObject) }
    }

    override suspend fun listRoutinesWithExercises(): List<RoutineWithExercises> {
        val data = client.request(Operations.ROUTINES)
        return (data["routines"]?.jsonArray ?: JsonArray(emptyList())).map {
            routineFromJson(remember(it.jsonObject))
        }
    }

    override suspend fun getRoutineWithExercises(routineId: String): RoutineWithExercises? =
        listRoutinesWithExercises().firstOrNull { it.id == routineId }

    // ==============================
    // 更新（オンライン必須）
    // ==============================
    //
    // 記録と違ってキューに積まない。
    // 圏外でルーティンを作れると、サーバの採番や検証を通っていない
    // ルーティンに対して記録が積まれ、整合を取る手段が無くなる。

    private fun exerciseInputsJson(input: RoutineInput) = buildJsonArray {
        input.exercises.forEach { e ->
            add(buildJsonObject {
                put("id", Uuid.v4())
                put("exerciseId", e.exerciseId)
                put("targetSets", e.targetSets)
                putOrNull("targetReps", e.targetReps)
                putOrNull("targetWeight", e.targetWeight)
                putOrNull("targetDurationSec", e.targetDurationSec)
                putOrNull("restSec", e.restSec)
            })
        }
    }

    override suspend fun createRoutine(input: RoutineInput): Routine {
        val data = client.request(
            Operations.CREATE_ROUTINE,
            buildJsonObject {
                put("id", Uuid.v4())
                put("name", input.name)
                putOrNull("description", input.description)
                put("icon", input.icon)
                put("color", input.color)
                put("frequencyType", input.frequencyType.uppercase())
                put("frequencyValue", input.frequencyValue)
                putJsonArray("frequencyDays") { input.frequencyDays.forEach { add(it) } }
                put("exercises", exerciseInputsJson(input))
            },
        )

        val routine = data["createRoutine"]!!.jsonObject.unwrapPayload("routine")
        return routineFromJson(remember(routine)).routine
    }

    override suspend fun updateRoutine(routineId: String, input: RoutineInput): Routine? {
        val data = client.request(
            Operations.UPDATE_ROUTINE,
            buildJsonObject {
                put("id", routineId)
                put("name", input.name)
                putOrNull("description", input.description)
                put("icon", input.icon)
                put("color", input.color)
                put("frequencyType", input.frequencyType.uppercase())
                put("frequencyValue", input.frequencyValue)
                putJsonArray("frequencyDays") { input.frequencyDays.forEach { add(it) } }
                put("isActive", input.isActive)
                // 直前に読んだ版を送る。他端末が先に更新していれば CONFLICT で弾かれる
                put("lockVersion", lockVersions[routineId] ?: 0)
                put("exercises", exerciseInputsJson(input))
            },
        )

        val routine = data["updateRoutine"]!!.jsonObject.unwrapPayload("routine")
        return routineFromJson(remember(routine)).routine
    }

    override suspend fun setRoutineActive(routineId: String, isActive: Boolean) {
        val data = client.request(
            Operations.SET_ROUTINE_ACTIVE,
            buildJsonObject {
                put("id", routineId)
                put("isActive", isActive)
            },
        )
        data["setRoutineActive"]!!.jsonObject.unwrapPayload("routine")
    }

    override suspend fun deleteRoutine(routineId: String) {
        val data = client.request(Operations.DELETE_ROUTINE, buildJsonObject { put("id", routineId) })
        data["deleteRoutine"]!!.jsonObject.unwrapPayload("routine")
        lockVersions.remove(routineId)
    }

    override suspend fun createCustomExercise(name: String, category: String, icon: String?): Exercise {
        val data = client.request(
            Operations.CREATE_CUSTOM_EXERCISE,
            buildJsonObject {
                put("id", Uuid.v4())
                put("name", name)
                put("category", category.uppercase())
                putOrNull("icon", icon)
            },
        )

        return exerciseFromJson(data["createCustomExercise"]!!.jsonObject.unwrapPayload("exercise"))
    }

    // ==============================
    // 記録（オフライン可）
    // ==============================

    override suspend fun saveWorkout(
        routineId: String,
        startedAt: String,
        durationSec: Int,
        exercises: List<SaveWorkoutExercise>,
        notes: String?,
    ): WorkoutSummary {
        val tally = tallyWorkout(exercises)
        val id = Uuid.v4()

        val sets = buildJsonArray {
            exercises.forEach { exercise ->
                exercise.sets.filter { it.completed }.forEach { set ->
                    add(buildJsonObject {
                        put("id", Uuid.v4())
                        put("routineExerciseId", exercise.routineExerciseId)
                        put("exerciseId", exercise.exerciseId)
                        put("setNumber", set.setNumber)
                        putOrNull("actualReps", set.reps)
                        putOrNull("actualWeight", set.weight)
                        putOrNull("actualDurationSec", set.durationSec)
                    })
                }
            }
        }

        // 「今日」は必ず端末が決める
        val startedOn = runCatching {
            kotlinx.datetime.Instant.parse(startedAt).toLocalDateTime(kotlinx.datetime.TimeZone.currentSystemDefault()).date
        }.getOrElse { com.myapplication.common.domain.today() }

        val variables = buildJsonObject {
            put("id", id)
            put("routineId", routineId)
            put("logDate", getDateString(startedOn))
            put("timeZone", client.timeZoneName())
            put("startedAt", startedAt)
            put("durationSec", durationSec)
            put("totalSets", tally.totalSets)
            put("sets", sets)
            put("clientMutationId", id)
        }

        return try {
            val data = client.request(Operations.RECORD_WORKOUT, variables)
            val payload = data["recordWorkout"]!!.jsonObject
            val summary = payload.unwrapPayload("summary")

            WorkoutSummary(
                routineLogId = summary["routineLogId"].str()!!,
                routineName = summary["routineName"].str() ?: "",
                durationSec = summary["durationSec"].int() ?: durationSec,
                completedSets = summary["completedSets"].int() ?: tally.completedSets,
                totalSets = summary["totalSets"].int() ?: tally.totalSets,
                totalVolume = summary["totalVolume"].dbl() ?: tally.totalVolume,
                status = (summary["status"].str() ?: LogStatus.SKIPPED).lowercase(),
            )
        } catch (e: NetworkFailure) {
            // 圏外。キューに積むので記録は失われない。
            // 結果画面を出すぶんの数字だけ手元で作る（サーバの判定と同じ基準）
            queue.enqueue(id, variables)

            WorkoutSummary(
                routineLogId = id,
                routineName = "",
                durationSec = durationSec,
                completedSets = tally.completedSets,
                totalSets = tally.totalSets,
                totalVolume = tally.totalVolume,
                status = resolveWorkoutStatus(tally.completedSets, tally.totalSets),
            )
        }
    }

    // ==============================
    // アカウント
    // ==============================
    //
    // メール登録は「新しいアカウントを作る」のではなく、
    // いまの匿名アカウントにメールとパスワードを足すだけ。
    // user.id が変わらないので、記録は1件も移動しない。

    private fun viewerFromJson(v: JsonObject) = Viewer(
        id = v["id"].str()!!,
        email = v["email"].str(),
        displayName = v["displayName"].str(),
        isAnonymous = v["isAnonymous"].bool() ?: true,
        emailVerified = v["emailVerified"].bool() ?: false,
    )

    suspend fun viewer(): Viewer {
        val data = client.request(Operations.VIEWER)
        return viewerFromJson(data["viewer"]!!.jsonObject)
    }

    /** 匿名アカウントにメールとパスワードを足す */
    suspend fun attachEmailPassword(email: String, password: String, displayName: String? = null): Viewer {
        val data = client.request(
            Operations.ATTACH_EMAIL_PASSWORD,
            buildJsonObject {
                put("email", email)
                put("password", password)
                putOrNull("displayName", displayName)
            },
        )
        return viewerFromJson(data["attachEmailPassword"]!!.jsonObject.unwrapPayload("viewer"))
    }

    /** 既にあるアカウントへ切り替える。トークンが差し替わる */
    suspend fun linkExistingAccount(email: String, password: String, merge: Boolean = false): Viewer {
        val data = client.request(
            Operations.LINK_EXISTING_ACCOUNT,
            buildJsonObject {
                put("email", email)
                put("password", password)
                put("merge", merge)
            },
        )

        val payload = data["linkExistingAccount"]!!.jsonObject
        val viewer = viewerFromJson(payload.unwrapPayload("viewer"))

        payload["token"].str()?.let { db.setMeta(apiToken = it) }
        return viewer
    }

    /** サインアウトしても記録は消えない。この端末から見えなくなるだけ */
    suspend fun signOut() {
        try {
            client.request(Operations.SIGN_OUT)
        } finally {
            db.setMeta(apiToken = "")
        }
    }

    // ==============================
    // 設定
    // ==============================

    override suspend fun getCounts(): DataCounts {
        val data = client.request(Operations.VIEWER)
        val counts = data["viewer"]!!.jsonObject["counts"]!!.jsonObject

        return DataCounts(
            routines = counts["routines"].int() ?: 0,
            exercises = counts["exercises"].int() ?: 0,
            routineLogs = counts["routineLogs"].int() ?: 0,
            exerciseLogs = counts["exerciseLogs"].int() ?: 0,
        )
    }

    /**
     * サーバのデータを全部消して初期状態に戻す。
     *
     * 端末側も一緒に作り直す。サーバだけ消すと、
     * 次の起動で端末のコピーが預け直されて復活してしまう。
     */
    override suspend fun resetAll() {
        client.request(Operations.RESET_DATA)
        local.resetAllLocal()
        importSnapshot(force = true)
    }

    override suspend fun pendingCount(): Int = queue.pending().size
}

// ==============================
// ヘルパー
// ==============================

private fun kotlinx.serialization.json.JsonObjectBuilder.putOrNull(key: String, value: String?) {
    if (value != null) put(key, value) else put(key, kotlinx.serialization.json.JsonNull)
}

private fun kotlinx.serialization.json.JsonObjectBuilder.putOrNull(key: String, value: Int?) {
    if (value != null) put(key, value) else put(key, kotlinx.serialization.json.JsonNull)
}

private fun kotlinx.serialization.json.JsonObjectBuilder.putOrNull(key: String, value: Double?) {
    if (value != null) put(key, value) else put(key, kotlinx.serialization.json.JsonNull)
}

private fun <T> jsonListOf(rows: List<T>, serializer: kotlinx.serialization.KSerializer<T>): JsonArray {
    val json = kotlinx.serialization.json.Json { encodeDefaults = true }
    return JsonArray(rows.map { json.encodeToJsonElement(serializer, it) })
}


