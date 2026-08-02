package com.myapplication.common.constants

import com.myapplication.common.data.ExerciseCategory

/**
 * プリセット種目のIDは固定値。
 * 端末ごとにランダムなUUIDを振ると、クラウド同期したときに
 * 同じ「腕立て伏せ」が複数生まれてしまう。
 * RN / Flutter / KMP の3実装で必ず同じ値を使うこと。
 */
fun presetId(n: Int): String = "00000000-0000-4000-8000-" + n.toString().padStart(12, '0')

data class PresetExercise(
    val id: String,
    val name: String,
    val category: String,
    val icon: String,
    /** 器具なしで今すぐできる種目。初期ルーティンの生成に使う */
    val bodyweight: Boolean = false,
    /** 回数ではなく秒数で計測する種目 */
    val timeBased: Boolean = false,
)

val presetExercises = listOf(
    // 胸
    PresetExercise(presetId(1), "ベンチプレス", ExerciseCategory.STRENGTH, "🏋️"),
    PresetExercise(presetId(2), "ダンベルフライ", ExerciseCategory.STRENGTH, "🦅"),
    PresetExercise(presetId(3), "腕立て伏せ", ExerciseCategory.STRENGTH, "💪", bodyweight = true),
    PresetExercise(presetId(4), "インクラインベンチプレス", ExerciseCategory.STRENGTH, "🏋️"),
    // 背中
    PresetExercise(presetId(5), "デッドリフト", ExerciseCategory.STRENGTH, "🏋️"),
    PresetExercise(presetId(6), "ラットプルダウン", ExerciseCategory.STRENGTH, "💪"),
    PresetExercise(presetId(7), "懸垂", ExerciseCategory.STRENGTH, "🔝", bodyweight = true),
    PresetExercise(presetId(8), "ベントオーバーロウ", ExerciseCategory.STRENGTH, "🏋️"),
    // 脚
    PresetExercise(presetId(9), "スクワット", ExerciseCategory.STRENGTH, "🦵", bodyweight = true),
    PresetExercise(presetId(10), "レッグプレス", ExerciseCategory.STRENGTH, "🦵"),
    PresetExercise(presetId(11), "レッグカール", ExerciseCategory.STRENGTH, "🦵"),
    PresetExercise(presetId(12), "カーフレイズ", ExerciseCategory.STRENGTH, "🦵", bodyweight = true),
    // 肩
    PresetExercise(presetId(13), "ショルダープレス", ExerciseCategory.STRENGTH, "💪"),
    PresetExercise(presetId(14), "サイドレイズ", ExerciseCategory.STRENGTH, "💪"),
    // 腕
    PresetExercise(presetId(15), "ダンベルカール", ExerciseCategory.STRENGTH, "💪"),
    PresetExercise(presetId(16), "トライセプスエクステンション", ExerciseCategory.STRENGTH, "💪"),
    // 腹筋・体幹
    PresetExercise(presetId(17), "腹筋（クランチ）", ExerciseCategory.STRENGTH, "🔥", bodyweight = true),
    PresetExercise(presetId(18), "プランク", ExerciseCategory.STRENGTH, "🔥", bodyweight = true, timeBased = true),
    PresetExercise(presetId(19), "レッグレイズ", ExerciseCategory.STRENGTH, "🔥", bodyweight = true),
    // 有酸素
    PresetExercise(presetId(20), "ランニング", ExerciseCategory.CARDIO, "🏃", bodyweight = true, timeBased = true),
    PresetExercise(presetId(21), "エアロバイク", ExerciseCategory.CARDIO, "🚴", timeBased = true),
    PresetExercise(presetId(22), "縄跳び", ExerciseCategory.CARDIO, "⏭️", bodyweight = true, timeBased = true),
    // ゲーム
    PresetExercise(presetId(23), "リングフィット", ExerciseCategory.GAME, "🎮", timeBased = true),
    PresetExercise(presetId(24), "フィットボクシング", ExerciseCategory.GAME, "🥊", timeBased = true),
    PresetExercise(presetId(25), "Just Dance", ExerciseCategory.GAME, "💃", timeBased = true),
)

val routineIcons = listOf("💪", "🏃", "🎮", "🏋️", "🚴", "🔥", "🧘‍♂️", "👟", "🎯", "⭐")
val routineColors = listOf("#6C5CE7", "#00B894", "#0984E3", "#D63031", "#FDCB6E", "#E84393", "#00CEC9", "#FF7675")

val categoryLabels = mapOf(
    ExerciseCategory.STRENGTH to "筋トレ",
    ExerciseCategory.CARDIO to "有酸素",
    ExerciseCategory.GAME to "ゲーム",
    ExerciseCategory.CUSTOM to "カスタム",
)

const val DEFAULT_REST_SEC = 60

data class StarterExercise(
    val exerciseId: String,
    val sets: Int,
    val reps: Int? = null,
    val durationSec: Int? = null,
    val restSec: Int,
)

/**
 * 初回起動時に自動で入るルーティン。
 * 「アプリを開いた瞬間に、いつものルーティンが始められる」状態にするためのもの。
 */
const val STARTER_ROUTINE_NAME = "いつものルーティン"

val starterRoutineExercises = listOf(
    StarterExercise(presetId(3), sets = 3, reps = 10, restSec = 60),
    StarterExercise(presetId(9), sets = 3, reps = 15, restSec = 60),
    StarterExercise(presetId(17), sets = 3, reps = 20, restSec = 45),
    StarterExercise(presetId(18), sets = 2, durationSec = 30, restSec = 45),
)
