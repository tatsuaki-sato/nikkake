package com.myapplication.common

import com.myapplication.common.data.Exercise
import com.myapplication.common.data.LocalDb
import com.myapplication.common.data.LogStatus
import com.myapplication.common.data.NetworkFailure
import com.myapplication.common.data.PermanentFailure
import com.myapplication.common.data.Repository
import com.myapplication.common.data.RoutineInput
import com.myapplication.common.data.SaveWorkoutExercise
import com.myapplication.common.data.ServerRepository
import com.myapplication.common.data.StorageAdapter
import com.myapplication.common.data.WorkoutSet
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.http.content.TextContent
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * サーバ実装の検証。
 *
 * 実サーバは立てず、GraphQL の応答だけを差し替える。
 * ここで確かめたいのは「サーバが返した形をそのまま画面へ渡せているか」と
 * 「圏外のときに記録を失わないか」で、Rails 側の正しさは RSpec が見ている。
 */
class ServerRepositoryTest {

    /** 応答を差し替えるだけの薄いテスト用エンジン */
    private class FakeTransport {
        private val replies = mutableMapOf<String, JsonObject>()
        private var failure: Throwable? = null
        var lastVariables: JsonObject = JsonObject(emptyMap())
            private set

        fun reply(operationHint: String, data: JsonObject) {
            replies[operationHint] = data
        }

        fun failWith(error: Throwable) {
            failure = error
        }

        fun recover() {
            failure = null
        }

        fun engine(): MockEngine = MockEngine { request ->
            failure?.let { throw it }

            val bodyText = (request.body as TextContent).text
            val body = Json.parseToJsonElement(bodyText).jsonObject
            val query = body["query"]?.toString() ?: ""
            lastVariables = body["variables"]?.jsonObject ?: JsonObject(emptyMap())

            val match = replies.entries.firstOrNull { query.contains(it.key) }
            val data = match?.value ?: JsonObject(emptyMap())

            respond(
                content = buildJsonObject { put("data", data) }.toString(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
    }

    private fun setUp(): Triple<LocalDb, Repository, Pair<ServerRepository, FakeTransport>> {
        val db = LocalDb(StorageAdapter.inMemory())
        val local = Repository(db)
        val transport = FakeTransport()
        val server = ServerRepository(
            db = db,
            local = local,
            endpoint = "http://example.test/graphql",
            httpClient = HttpClient(transport.engine()),
        )
        return Triple(db, local, server to transport)
    }

    // ==============================
    // 遅延登録
    // ==============================

    @Test
    fun 匿名アカウントのトークンを保存する() = runTest {
        val (db, _, pair) = setUp()
        val (server, transport) = pair
        local_seed(db)

        transport.reply(
            "createAnonymousAccount",
            buildJsonObject {
                put("createAnonymousAccount", buildJsonObject {
                    put("token", "tok_abc")
                    put("userErrors", kotlinx.serialization.json.JsonArray(emptyList()))
                })
            },
        )

        assertEquals("tok_abc", server.ensureSession())
        assertEquals("tok_abc", db.getMeta().apiToken)
    }

    @Test
    fun 圏外でも例外を投げない_次の起動で再試行できる() = runTest {
        val (db, _, pair) = setUp()
        val (server, transport) = pair

        transport.failWith(NetworkFailure("圏外"))

        assertNull(server.ensureSession())
        assertNull(db.getMeta().apiToken)
    }

    @Test
    fun 端末側でシードするのでサーバには初期ルーティンを作らせない() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "createAnonymousAccount",
            buildJsonObject {
                put("createAnonymousAccount", buildJsonObject {
                    put("token", "tok_abc")
                    put("userErrors", kotlinx.serialization.json.JsonArray(emptyList()))
                })
            },
        )

        server.suppressStarterRoutine()
        server.ensureSession()

        assertEquals(false, transport.lastVariables["withStarterRoutine"]?.let { it.toString() == "true" })
    }

    @Test
    fun 預け入れは一度きり_二度目は送らない() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "importSnapshot",
            buildJsonObject {
                put("importSnapshot", buildJsonObject {
                    put("imported", JsonObject(emptyMap()))
                    put("userErrors", kotlinx.serialization.json.JsonArray(emptyList()))
                })
            },
        )

        assertTrue(server.importSnapshot())
        assertTrue(!server.importSnapshot())

        // 切り替え直前の書き込みを拾うときだけ、明示的に送り直せる
        assertTrue(server.importSnapshot(force = true))
    }

    // ==============================
    // 参照
    // ==============================

    @Test
    fun ホームの区分をサーバの応答どおりに渡す() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "query Home",
            buildJsonObject {
                put("home", buildJsonObject {
                    put("today", "2026-08-02")
                    put("streak", buildJsonObject {
                        put("current", 3); put("longest", 5); put("lastCompletedDate", "2026-08-02")
                    })
                    put("due", kotlinx.serialization.json.JsonArray(listOf(
                        todayRoutineJson(name = "朝トレ", isDueToday = true, label = "毎日"),
                    )))
                    put("notScheduled", kotlinx.serialization.json.JsonArray(emptyList()))
                    put("completed", kotlinx.serialization.json.JsonArray(listOf(
                        todayRoutineJson(name = "夜トレ", isCompleted = true, label = "3日ごと"),
                    )))
                })
            },
        )

        val home = server.getHome()

        assertEquals("2026-08-02", home.today)
        assertEquals(3, home.streak.current)
        assertEquals("朝トレ", home.due.single().routine.name)
        // 頻度の文言はサーバが返す。手元で組み立てない
        assertEquals("毎日", home.due.single().frequencyLabel)
        assertTrue(home.completed.single().isCompleted)
        assertEquals(2, home.total)
    }

    @Test
    fun 前回の記録の文言はサーバのものをそのまま出す() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "query WorkoutSession",
            buildJsonObject {
                put("workoutSession", buildJsonObject {
                    put("routine", routineJson(name = "テスト"))
                    put("exercises", kotlinx.serialization.json.JsonArray(listOf(
                        buildJsonObject {
                            put("routineExerciseId", "re1")
                            put("exercise", exerciseJson())
                            put("targetSets", 3)
                            put("targetReps", 10)
                            put("targetWeight", 50.0)
                            put("targetDurationSec", kotlinx.serialization.json.JsonNull)
                            put("restSec", 90)
                            put("previousLabel", "50×10 / 50×9")
                            put("previousSets", kotlinx.serialization.json.JsonArray(listOf(
                                buildJsonObject { put("setNumber", 1); put("reps", 10); put("weight", 50.0); put("durationSec", kotlinx.serialization.json.JsonNull) },
                                buildJsonObject { put("setNumber", 2); put("reps", 9); put("weight", 50.0); put("durationSec", kotlinx.serialization.json.JsonNull) },
                            )))
                        },
                    )))
                })
            },
        )

        val session = server.getWorkoutSession("r1")!!

        assertEquals("50×10 / 50×9", session.exercises.single().previousLabel)
        assertEquals(2, session.exercises.single().previousSets.size)
        assertEquals(90, session.exercises.single().restSec)
    }

    // ==============================
    // 記録
    // ==============================

    private fun sampleExercises() = listOf(
        SaveWorkoutExercise(
            routineExerciseId = "re1",
            exerciseId = "e1",
            sets = listOf(
                WorkoutSet(setNumber = 1, reps = 10, weight = 50.0, completed = true),
                WorkoutSet(setNumber = 2, reps = 10, weight = 50.0, completed = false),
            ),
        ),
    )

    @Test
    fun サーバが返したサマリーをそのまま使う() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "mutation RecordWorkout",
            buildJsonObject {
                put("recordWorkout", buildJsonObject {
                    put("summary", buildJsonObject {
                        put("routineLogId", "log1")
                        put("routineName", "テスト")
                        put("durationSec", 300)
                        put("completedSets", 1)
                        put("totalSets", 2)
                        put("totalVolume", 500.0)
                        put("status", "PARTIAL")
                    })
                    put("streak", buildJsonObject { put("current", 1); put("longest", 1); put("lastCompletedDate", "2026-08-02") })
                    put("userErrors", kotlinx.serialization.json.JsonArray(emptyList()))
                })
            },
        )

        val summary = server.saveWorkout(
            routineId = "r1",
            startedAt = "2026-08-02T07:00:00Z",
            durationSec = 300,
            exercises = sampleExercises(),
        )

        assertEquals(LogStatus.PARTIAL, summary.status)
        assertEquals(1, summary.completedSets)
        // 総セット数はサーバが status を判定するのに要る
        assertEquals(2, (transport.lastVariables["totalSets"] as kotlinx.serialization.json.JsonPrimitive).content.toInt())
        assertEquals("2026-08-02", (transport.lastVariables["logDate"] as kotlinx.serialization.json.JsonPrimitive).content)
    }

    @Test
    fun 圏外ならキューに積み画面には暫定のサマリーを返す() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.failWith(NetworkFailure("圏外"))

        val summary = server.saveWorkout(
            routineId = "r1",
            startedAt = "2026-08-02T07:00:00Z",
            durationSec = 300,
            exercises = sampleExercises(),
        )

        // 記録は失われない
        assertEquals(1, server.queue.pending().size)
        assertEquals(1, server.pendingCount())

        // サーバと同じ基準で判定した結果が出る
        assertEquals(LogStatus.PARTIAL, summary.status)
        assertEquals(1, summary.completedSets)
        assertEquals(500.0, summary.totalVolume)
    }

    @Test
    fun 復帰すると溜まった記録が送られキューが空になる() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.failWith(NetworkFailure("圏外"))
        server.saveWorkout(
            routineId = "r1",
            startedAt = "2026-08-02T07:00:00Z",
            durationSec = 300,
            exercises = sampleExercises(),
        )

        transport.recover()
        transport.reply(
            "mutation RecordWorkout",
            buildJsonObject {
                put("recordWorkout", buildJsonObject {
                    put("summary", kotlinx.serialization.json.JsonNull)
                    put("streak", kotlinx.serialization.json.JsonNull)
                    put("userErrors", kotlinx.serialization.json.JsonArray(emptyList()))
                })
            },
        )

        assertEquals(1, server.flushQueue())
        assertTrue(server.queue.pending().isEmpty())
    }

    @Test
    fun 再送しても同じIDなので二重登録されない() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.failWith(NetworkFailure("圏外"))
        server.saveWorkout(
            routineId = "r1",
            startedAt = "2026-08-02T07:00:00Z",
            durationSec = 300,
            exercises = sampleExercises(),
        )

        val queued = server.queue.pending().single()
        assertEquals(queued.id, (queued.payload["clientMutationId"] as kotlinx.serialization.json.JsonPrimitive).content)

        // 同じIDを積み直しても増えない
        server.queue.enqueue(queued.id, queued.payload)
        assertEquals(1, server.queue.pending().size)
    }

    // ==============================
    // 更新
    // ==============================

    @Test
    fun userErrorsはそのまま画面に出せる例外になる() = runTest {
        val (_, _, pair) = setUp()
        val (server, transport) = pair

        transport.reply(
            "mutation CreateRoutine",
            buildJsonObject {
                put("createRoutine", buildJsonObject {
                    put("routine", kotlinx.serialization.json.JsonNull)
                    put("userErrors", kotlinx.serialization.json.JsonArray(listOf(
                        buildJsonObject {
                            put("message", "名前を入力してください")
                            put("code", "VALIDATION")
                            put("path", kotlinx.serialization.json.JsonArray(listOf(kotlinx.serialization.json.JsonPrimitive("name"))))
                        },
                    )))
                })
            },
        )

        val error = assertFailsWith<PermanentFailure> {
            server.createRoutine(RoutineInput(name = "", icon = "💪", color = "#6C5CE7"))
        }
        assertEquals("名前を入力してください", error.message)
    }

    // ==============================
    // ヘルパー
    // ==============================

    private suspend fun local_seed(db: LocalDb) {
        Repository(db).seedIfNeededLocal()
    }

    private fun exerciseJson() = buildJsonObject {
        put("id", "e1"); put("name", "腕立て伏せ"); put("category", "STRENGTH")
        put("icon", "💪"); put("isPreset", true)
    }

    private fun routineJson(name: String) = buildJsonObject {
        put("id", "r1"); put("name", name); put("description", kotlinx.serialization.json.JsonNull)
        put("color", "#6C5CE7"); put("icon", "💪"); put("frequencyType", "DAILY")
        put("frequencyValue", 1); put("frequencyDays", kotlinx.serialization.json.JsonArray(emptyList()))
        put("isActive", true); put("sortOrder", 0); put("lockVersion", 2)
        put("routineExercises", kotlinx.serialization.json.JsonArray(listOf(
            buildJsonObject {
                put("id", "re1"); put("sortOrder", 0); put("targetSets", 3)
                put("targetReps", 10); put("targetWeight", kotlinx.serialization.json.JsonNull)
                put("targetDurationSec", kotlinx.serialization.json.JsonNull); put("restSec", 60)
                put("exercise", exerciseJson())
            },
        )))
    }

    private fun todayRoutineJson(
        name: String,
        isDueToday: Boolean = false,
        isCompleted: Boolean = false,
        label: String = "毎日",
    ) = buildJsonObject {
        put("routine", routineJson(name))
        put("isDueToday", isDueToday)
        put("isCompleted", isCompleted)
        put("frequencyLabel", label)
    }
}
