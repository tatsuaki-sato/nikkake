package com.myapplication.common.data

import kotlinx.datetime.LocalDate

/**
 * 画面が触るデータAPIの契約。
 *
 * 実装は2つある。
 *   Repository        端末ストレージが真実の源。ネットワークを使わない
 *   ServerRepository  Rails の GraphQL が真実の源。集計もサーバが返す
 *
 * どちらを使うかは実行時に決まる（遅延登録。docs/ARCHITECTURE.md 参照）。
 * **片方だけにメソッドを生やさないこと。** ここが両方を縛っているので、
 * 形が食い違えばコンパイルが落ちる。
 *
 * すべて suspend なのはサーバ実装が通信を伴うため。
 * ローカル実装は即座に返すが、シグネチャは揃える。
 */
interface NikkakeRepository {

    /** 端末に初期データを用意する。ネットワークを使わないので必ず終わる */
    suspend fun seedIfNeeded(): Boolean

    // ---------- 集計済みビュー ----------
    //
    // 対応するサーバ側は HomeViewBuilder / ProgressViewBuilder / WorkoutSessionBuilder。
    // 区分の基準や並び順を変えるときは両方直すこと。

    suspend fun getHome(todayDate: LocalDate? = null): HomeView
    suspend fun getProgress(rangeDays: Int = 7, todayDate: LocalDate? = null): ProgressView
    suspend fun getExerciseProgressPoints(exerciseId: String, limit: Int = 8): List<ExerciseProgressPoint>
    suspend fun getWorkoutSession(routineId: String): WorkoutSessionView?

    // ---------- 参照 ----------

    suspend fun listExercises(): List<Exercise>
    suspend fun listRoutinesWithExercises(): List<RoutineWithExercises>
    suspend fun getRoutineWithExercises(routineId: String): RoutineWithExercises?

    // ---------- 更新 ----------

    suspend fun createCustomExercise(name: String, category: String, icon: String?): Exercise
    suspend fun createRoutine(input: RoutineInput): Routine
    suspend fun updateRoutine(routineId: String, input: RoutineInput): Routine?
    suspend fun setRoutineActive(routineId: String, isActive: Boolean)
    suspend fun deleteRoutine(routineId: String)

    // ---------- 記録 ----------

    /**
     * status は受け取らない。完了セット数から実装側が必ず導出する。
     * 呼び出し側に決めさせると、サーバの判定基準とずれても誰も気づけない。
     */
    suspend fun saveWorkout(
        routineId: String,
        startedAt: String,
        durationSec: Int,
        exercises: List<SaveWorkoutExercise>,
        notes: String? = null,
    ): WorkoutSummary

    // ---------- 設定 ----------

    suspend fun getCounts(): DataCounts
    suspend fun resetAll()

    /** 送信待ちの記録の件数。ローカル実装では常に0 */
    suspend fun pendingCount(): Int
}

/** ホーム1枚ぶん。区分も連続記録もサーバが決める */
data class HomeView(
    val today: String = "",
    val streak: StreakInfo = StreakInfo(0, 0, null),
    val due: List<TodayRoutine> = emptyList(),
    val notScheduled: List<TodayRoutine> = emptyList(),
    val completed: List<TodayRoutine> = emptyList(),
) {
    val total: Int get() = due.size + notScheduled.size + completed.size
}

/** 進捗1枚ぶん */
data class ProgressView(
    val overall: OverallStats = OverallStats(),
    val streak: StreakInfo = StreakInfo(0, 0, null),
    val dailyStats: List<DailyStats> = emptyList(),
    val completedDates: Set<String> = emptySet(),
    val exercisesWithLogs: List<Exercise> = emptyList(),
)

/** ワークアウト実行に必要なもの一式。「前回の記録」も解決済み */
data class WorkoutSessionView(
    val routine: RoutineWithExercises,
    val exercises: List<WorkoutSessionEntry>,
)

data class WorkoutSessionEntry(
    val routineExerciseId: String,
    val exercise: Exercise,
    val targetSets: Int,
    val targetReps: Int? = null,
    val targetWeight: Double? = null,
    val targetDurationSec: Int? = null,
    val restSec: Int = 60,
    val previousSets: List<WorkoutSet> = emptyList(),
    /** 「50×10 / 50×9」。サーバが返す文言をそのまま出す */
    val previousLabel: String? = null,
)

data class DataCounts(
    val routines: Int = 0,
    val exercises: Int = 0,
    val routineLogs: Int = 0,
    val exerciseLogs: Int = 0,
)

/**
 * サーバから見た「いまのアカウント」。
 *
 * isAnonymous が true なら、記録を取り戻す手段がこの端末のトークンしか無い。
 * メール登録すると false になるが、user.id は変わらないので記録は移動しない。
 */
data class Viewer(
    val id: String,
    val email: String? = null,
    val displayName: String? = null,
    val isAnonymous: Boolean = true,
    val emailVerified: Boolean = false,
)
