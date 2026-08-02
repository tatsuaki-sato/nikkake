import '../models/models.dart';

/// プリセット種目のIDは固定値。
/// 端末ごとにランダムなUUIDを振ると、クラウド同期したときに
/// 同じ「腕立て伏せ」が複数生まれてしまう。
/// RN / Flutter / KMP の3実装で必ず同じ値を使うこと。
String presetId(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

class PresetExercise {
  final String id;
  final String name;
  final ExerciseCategory category;
  final String icon;

  /// 器具なしで今すぐできる種目。初期ルーティンの生成に使う
  final bool bodyweight;

  /// 回数ではなく秒数で計測する種目
  final bool timeBased;

  const PresetExercise({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    this.bodyweight = false,
    this.timeBased = false,
  });
}

const presetExercises = <PresetExercise>[
  // 胸
  PresetExercise(id: '00000000-0000-4000-8000-000000000001', name: 'ベンチプレス', category: ExerciseCategory.strength, icon: '🏋️'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000002', name: 'ダンベルフライ', category: ExerciseCategory.strength, icon: '🦅'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000003', name: '腕立て伏せ', category: ExerciseCategory.strength, icon: '💪', bodyweight: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000004', name: 'インクラインベンチプレス', category: ExerciseCategory.strength, icon: '🏋️'),
  // 背中
  PresetExercise(id: '00000000-0000-4000-8000-000000000005', name: 'デッドリフト', category: ExerciseCategory.strength, icon: '🏋️'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000006', name: 'ラットプルダウン', category: ExerciseCategory.strength, icon: '💪'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000007', name: '懸垂', category: ExerciseCategory.strength, icon: '🔝', bodyweight: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000008', name: 'ベントオーバーロウ', category: ExerciseCategory.strength, icon: '🏋️'),
  // 脚
  PresetExercise(id: '00000000-0000-4000-8000-000000000009', name: 'スクワット', category: ExerciseCategory.strength, icon: '🦵', bodyweight: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000010', name: 'レッグプレス', category: ExerciseCategory.strength, icon: '🦵'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000011', name: 'レッグカール', category: ExerciseCategory.strength, icon: '🦵'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000012', name: 'カーフレイズ', category: ExerciseCategory.strength, icon: '🦵', bodyweight: true),
  // 肩
  PresetExercise(id: '00000000-0000-4000-8000-000000000013', name: 'ショルダープレス', category: ExerciseCategory.strength, icon: '💪'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000014', name: 'サイドレイズ', category: ExerciseCategory.strength, icon: '💪'),
  // 腕
  PresetExercise(id: '00000000-0000-4000-8000-000000000015', name: 'ダンベルカール', category: ExerciseCategory.strength, icon: '💪'),
  PresetExercise(id: '00000000-0000-4000-8000-000000000016', name: 'トライセプスエクステンション', category: ExerciseCategory.strength, icon: '💪'),
  // 腹筋・体幹
  PresetExercise(id: '00000000-0000-4000-8000-000000000017', name: '腹筋（クランチ）', category: ExerciseCategory.strength, icon: '🔥', bodyweight: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000018', name: 'プランク', category: ExerciseCategory.strength, icon: '🔥', bodyweight: true, timeBased: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000019', name: 'レッグレイズ', category: ExerciseCategory.strength, icon: '🔥', bodyweight: true),
  // 有酸素
  PresetExercise(id: '00000000-0000-4000-8000-000000000020', name: 'ランニング', category: ExerciseCategory.cardio, icon: '🏃', bodyweight: true, timeBased: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000021', name: 'エアロバイク', category: ExerciseCategory.cardio, icon: '🚴', timeBased: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000022', name: '縄跳び', category: ExerciseCategory.cardio, icon: '⏭️', bodyweight: true, timeBased: true),
  // ゲーム
  PresetExercise(id: '00000000-0000-4000-8000-000000000023', name: 'リングフィット', category: ExerciseCategory.game, icon: '🎮', timeBased: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000024', name: 'フィットボクシング', category: ExerciseCategory.game, icon: '🥊', timeBased: true),
  PresetExercise(id: '00000000-0000-4000-8000-000000000025', name: 'Just Dance', category: ExerciseCategory.game, icon: '💃', timeBased: true),
];

const routineIcons = ['💪', '🏃', '🎮', '🏋️', '🚴', '🔥', '🧘‍♂️', '👟', '🎯', '⭐'];
const routineColors = ['#6C5CE7', '#00B894', '#0984E3', '#D63031', '#FDCB6E', '#E84393', '#00CEC9', '#FF7675'];

const categoryLabels = {
  ExerciseCategory.strength: '筋トレ',
  ExerciseCategory.cardio: '有酸素',
  ExerciseCategory.game: 'ゲーム',
  ExerciseCategory.custom: 'カスタム',
};

const defaultRestSec = 60;

class StarterExercise {
  final String exerciseId;
  final int sets;
  final int? reps;
  final int? durationSec;
  final int restSec;

  const StarterExercise({
    required this.exerciseId,
    required this.sets,
    this.reps,
    this.durationSec,
    required this.restSec,
  });
}

/// 初回起動時に自動で入るルーティン。
/// 「アプリを開いた瞬間に、いつものルーティンが始められる」状態にするためのもの。
const starterRoutineName = 'いつものルーティン';

const starterRoutineExercises = <StarterExercise>[
  StarterExercise(exerciseId: '00000000-0000-4000-8000-000000000003', sets: 3, reps: 10, restSec: 60),
  StarterExercise(exerciseId: '00000000-0000-4000-8000-000000000009', sets: 3, reps: 15, restSec: 60),
  StarterExercise(exerciseId: '00000000-0000-4000-8000-000000000017', sets: 3, reps: 20, restSec: 45),
  StarterExercise(exerciseId: '00000000-0000-4000-8000-000000000018', sets: 2, durationSec: 30, restSec: 45),
];
