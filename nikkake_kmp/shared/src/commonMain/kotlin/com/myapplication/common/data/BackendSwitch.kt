package com.myapplication.common.data

import io.ktor.client.HttpClient
import kotlinx.datetime.LocalDate

/**
 * データの取得元。
 *
 * local  : 端末のストレージが真実の源。ネットワークを一切使わない（移行前の挙動）
 * server : Rails の GraphQL が真実の源。集計もサーバが返す
 *
 * 移行中は両方を残し、同じテストが両方で通ることを
 * 「挙動が変わっていない」ことの証明にしている。
 */
enum class Backend { LOCAL, SERVER }

/**
 * 実行時の切り替えを担う。
 *
 * サーバモードでも、サーバへの登録と端末データの預け入れが済むまでは
 * ローカル実装で動く（遅延登録）。こうしないと、アプリを入れた直後に
 * 圏外だとホームが空になる。
 *
 * **実装を起動時に固定してはいけない。** 固定するとローカルのまま戻らない。
 * そのため自身が NikkakeRepository として振る舞い、呼び出しのたびに
 * current へ委譲する。画面もストアも切り替えを意識しなくてよい。
 */
class BackendSwitch(
    val db: LocalDb,
    backend: Backend,
    endpoint: String,
    httpClient: HttpClient? = null,
    timeZoneName: () -> String = { "Asia/Tokyo" },
) : NikkakeRepository {

    val local: Repository = Repository(db)

    val server: ServerRepository? = if (backend == Backend.SERVER) {
        ServerRepository(
            db = db,
            local = local,
            endpoint = endpoint,
            httpClient = httpClient ?: HttpClient(),
            timeZoneName = timeZoneName,
        )
    } else {
        null
    }

    private var ready = false

    /** サーバの応答を使ってよいか。false のあいだはローカル実装で動く */
    val isServerReady: Boolean get() = ready && server != null

    val current: NikkakeRepository get() = if (isServerReady) server!! else local

    /** 画面を出すのに必要な準備。ネットワークを使わないので必ず終わる */
    suspend fun prepareLocalData(): Boolean = local.seedIfNeededLocal()

    /**
     * サーバへの遅延登録。呼び出し側は結果を待たない。
     * 失敗しても例外を投げない（起動を巻き添えにしない）。
     */
    suspend fun registerInBackground(): Boolean {
        val api = server ?: return false

        return try {
            // 端末側でシード済みなので、サーバにもう1つ作らせない。
            // 両方で作ると「いつものルーティン」が2つ並ぶ
            api.suppressStarterRoutine()

            val token = api.ensureSession() ?: return false

            api.importSnapshot()

            // ここから先はサーバが真実の源
            ready = true

            // 切り替えの直前に端末へ書かれた分を拾う。
            // 登録が終わる前でもユーザーは操作できる（それがこの設計の目的）ので、
            // 1回目の預け入れと切り替えのあいだに書かれた記録が取り残される。
            // ID は端末生成で ON CONFLICT DO NOTHING に吸収されるため再送は安全。
            api.importSnapshot(force = true)

            // 圏外中に溜まった記録を送る（結果は待たない）
            api.flushQueue()

            true
        } catch (e: Exception) {
            // 圏外・サーバ停止・不正な応答。次の起動で再試行する
            false
        }
    }

    // ==============================
    // 委譲
    // ==============================
    //
    // 呼び出しのたびに current を引く。ここを変数に束ねてはいけない。

    override suspend fun seedIfNeeded(): Boolean = current.seedIfNeeded()

    override suspend fun getHome(todayDate: LocalDate?): HomeView = current.getHome(todayDate)

    override suspend fun getProgress(rangeDays: Int, todayDate: LocalDate?): ProgressView =
        current.getProgress(rangeDays, todayDate)

    override suspend fun getExerciseProgressPoints(exerciseId: String, limit: Int): List<ExerciseProgressPoint> =
        current.getExerciseProgressPoints(exerciseId, limit)

    override suspend fun getWorkoutSession(routineId: String): WorkoutSessionView? =
        current.getWorkoutSession(routineId)

    override suspend fun listExercises(): List<Exercise> = current.listExercises()

    override suspend fun listRoutinesWithExercises(): List<RoutineWithExercises> =
        current.listRoutinesWithExercises()

    override suspend fun getRoutineWithExercises(routineId: String): RoutineWithExercises? =
        current.getRoutineWithExercises(routineId)

    override suspend fun createCustomExercise(name: String, category: String, icon: String?): Exercise =
        current.createCustomExercise(name, category, icon)

    override suspend fun createRoutine(input: RoutineInput): Routine = current.createRoutine(input)

    override suspend fun updateRoutine(routineId: String, input: RoutineInput): Routine? =
        current.updateRoutine(routineId, input)

    override suspend fun setRoutineActive(routineId: String, isActive: Boolean) =
        current.setRoutineActive(routineId, isActive)

    override suspend fun deleteRoutine(routineId: String) = current.deleteRoutine(routineId)

    override suspend fun saveWorkout(
        routineId: String,
        startedAt: String,
        durationSec: Int,
        exercises: List<SaveWorkoutExercise>,
        notes: String?,
    ): WorkoutSummary = current.saveWorkout(routineId, startedAt, durationSec, exercises, notes)

    override suspend fun getCounts(): DataCounts = current.getCounts()

    override suspend fun resetAll() = current.resetAll()

    override suspend fun pendingCount(): Int = current.pendingCount()
}
