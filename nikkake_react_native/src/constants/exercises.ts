import { ExerciseCategory } from '../../types';

export const EXERCISE_CATEGORIES: { id: ExerciseCategory; name: string }[] = [
  { id: 'strength', name: '筋トレ' },
  { id: 'cardio', name: '有酸素' },
  { id: 'game', name: 'ゲーム' },
  { id: 'custom', name: 'カスタム' },
];

export interface PresetExercise {
  id: string;
  name: string;
  category: ExerciseCategory;
  icon: string;
  /** 器具なしで今すぐできる種目。初期ルーティンの自動生成に使う */
  bodyweight: boolean;
  /** 回数ではなく秒数で計測する種目 */
  timeBased: boolean;
}

/**
 * プリセット種目のIDは固定値にしてある。
 * 端末ごとにランダムなUUIDを振ると、クラウド同期したときに
 * 同じ「腕立て伏せ」が複数生まれてしまうため。
 * 3実装(RN/Flutter/KMP)で必ず同じ値を使うこと。
 */
const presetId = (n: number): string =>
  `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;

export const PRESET_EXERCISES: PresetExercise[] = [
  // 胸
  { id: presetId(1), name: 'ベンチプレス', category: 'strength', icon: '🏋️', bodyweight: false, timeBased: false },
  { id: presetId(2), name: 'ダンベルフライ', category: 'strength', icon: '🦅', bodyweight: false, timeBased: false },
  { id: presetId(3), name: '腕立て伏せ', category: 'strength', icon: '💪', bodyweight: true, timeBased: false },
  { id: presetId(4), name: 'インクラインベンチプレス', category: 'strength', icon: '🏋️', bodyweight: false, timeBased: false },
  // 背中
  { id: presetId(5), name: 'デッドリフト', category: 'strength', icon: '🏋️', bodyweight: false, timeBased: false },
  { id: presetId(6), name: 'ラットプルダウン', category: 'strength', icon: '💪', bodyweight: false, timeBased: false },
  { id: presetId(7), name: '懸垂', category: 'strength', icon: '🔝', bodyweight: true, timeBased: false },
  { id: presetId(8), name: 'ベントオーバーロウ', category: 'strength', icon: '🏋️', bodyweight: false, timeBased: false },
  // 脚
  { id: presetId(9), name: 'スクワット', category: 'strength', icon: '🦵', bodyweight: true, timeBased: false },
  { id: presetId(10), name: 'レッグプレス', category: 'strength', icon: '🦵', bodyweight: false, timeBased: false },
  { id: presetId(11), name: 'レッグカール', category: 'strength', icon: '🦵', bodyweight: false, timeBased: false },
  { id: presetId(12), name: 'カーフレイズ', category: 'strength', icon: '🦵', bodyweight: true, timeBased: false },
  // 肩
  { id: presetId(13), name: 'ショルダープレス', category: 'strength', icon: '💪', bodyweight: false, timeBased: false },
  { id: presetId(14), name: 'サイドレイズ', category: 'strength', icon: '💪', bodyweight: false, timeBased: false },
  // 腕
  { id: presetId(15), name: 'ダンベルカール', category: 'strength', icon: '💪', bodyweight: false, timeBased: false },
  { id: presetId(16), name: 'トライセプスエクステンション', category: 'strength', icon: '💪', bodyweight: false, timeBased: false },
  // 腹筋・体幹
  { id: presetId(17), name: '腹筋（クランチ）', category: 'strength', icon: '🔥', bodyweight: true, timeBased: false },
  { id: presetId(18), name: 'プランク', category: 'strength', icon: '🔥', bodyweight: true, timeBased: true },
  { id: presetId(19), name: 'レッグレイズ', category: 'strength', icon: '🔥', bodyweight: true, timeBased: false },
  // 有酸素
  { id: presetId(20), name: 'ランニング', category: 'cardio', icon: '🏃', bodyweight: true, timeBased: true },
  { id: presetId(21), name: 'エアロバイク', category: 'cardio', icon: '🚴', bodyweight: false, timeBased: true },
  { id: presetId(22), name: '縄跳び', category: 'cardio', icon: '⏭️', bodyweight: true, timeBased: true },
  // ゲーム
  { id: presetId(23), name: 'リングフィット', category: 'game', icon: '🎮', bodyweight: false, timeBased: true },
  { id: presetId(24), name: 'フィットボクシング', category: 'game', icon: '🥊', bodyweight: false, timeBased: true },
  { id: presetId(25), name: 'Just Dance', category: 'game', icon: '💃', bodyweight: false, timeBased: true },
];

export const findPresetExercise = (id: string): PresetExercise | undefined =>
  PRESET_EXERCISES.find(e => e.id === id);

export const ROUTINE_ICONS = ['💪', '🏃', '🎮', '🏋️', '🚴', '🔥', '🧘‍♂️', '👟', '🎯', '⭐'];
export const ROUTINE_COLORS = ['#6C5CE7', '#00B894', '#0984E3', '#D63031', '#FDCB6E', '#E84393', '#00CEC9', '#FF7675'];

/**
 * 初回起動時に自動で入るルーティン。
 * 「アプリを開いた瞬間に、いつものルーティンが始められる」状態にするためのもの。
 * 器具なしで自宅でできる種目だけで構成する。
 */
export const STARTER_ROUTINE = {
  name: 'いつものルーティン',
  icon: '💪',
  color: '#6C5CE7',
  exercises: [
    { exerciseId: presetId(3), sets: 3, reps: 10, durationSec: null, restSec: 60 },   // 腕立て伏せ
    { exerciseId: presetId(9), sets: 3, reps: 15, durationSec: null, restSec: 60 },   // スクワット
    { exerciseId: presetId(17), sets: 3, reps: 20, durationSec: null, restSec: 45 },  // 腹筋
    { exerciseId: presetId(18), sets: 2, reps: null, durationSec: 30, restSec: 45 },  // プランク
  ],
};

export const DEFAULT_REST_SEC = 60;
