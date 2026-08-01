-- ============================================
-- nikkake - データベースセットアップSQL
-- Supabase SQL Editor に貼り付けて実行してください
-- ============================================

-- ============================================
-- 1. テーブル作成
-- ============================================

-- プロフィール（auth.usersと紐付け）
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- エクササイズマスタ（プリセット + カスタム）
CREATE TABLE exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('strength', 'cardio', 'game', 'custom')),
  description TEXT,
  icon TEXT,
  is_preset BOOLEAN DEFAULT FALSE NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ルーティン定義
CREATE TABLE routines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#6C5CE7',
  icon TEXT DEFAULT '💪',
  frequency_type TEXT NOT NULL CHECK (frequency_type IN ('daily', 'every_n_days', 'weekly')),
  frequency_value INTEGER DEFAULT 1,
  frequency_days INTEGER[] DEFAULT '{}',
  preferred_time TIME,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ルーティンに含まれるエクササイズ
CREATE TABLE routine_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id UUID NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  sort_order INTEGER DEFAULT 0 NOT NULL,
  target_sets INTEGER DEFAULT 3,
  target_reps INTEGER,
  target_weight REAL,
  target_duration_sec INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ルーティン実行ログ
CREATE TABLE routine_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id UUID NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  log_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL CHECK (status IN ('completed', 'partial', 'skipped')) DEFAULT 'completed',
  duration_sec INTEGER,
  notes TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- エクササイズごとの実行ログ
CREATE TABLE exercise_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_log_id UUID NOT NULL REFERENCES routine_logs(id) ON DELETE CASCADE,
  routine_exercise_id UUID NOT NULL REFERENCES routine_exercises(id) ON DELETE CASCADE,
  set_number INTEGER NOT NULL,
  actual_reps INTEGER,
  actual_weight REAL,
  actual_duration_sec INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 2. インデックス（検索高速化）
-- ============================================

CREATE INDEX idx_routines_user_id ON routines(user_id);
CREATE INDEX idx_routine_logs_user_date ON routine_logs(user_id, log_date);
CREATE INDEX idx_routine_logs_routine_id ON routine_logs(routine_id);
CREATE INDEX idx_exercise_logs_routine_log ON exercise_logs(routine_log_id);
CREATE INDEX idx_routine_exercises_routine ON routine_exercises(routine_id);

-- ============================================
-- 3. RLSポリシー（セキュリティ）
-- ============================================

-- profiles: 自分のプロフィールだけ読み書き可能
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);

-- exercises: プリセットは全員読める、カスタムは自分だけ
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "exercises_select" ON exercises FOR SELECT USING (
  is_preset = TRUE OR created_by = auth.uid()
);
CREATE POLICY "exercises_insert_own" ON exercises FOR INSERT WITH CHECK (
  auth.uid() = created_by AND is_preset = FALSE
);
CREATE POLICY "exercises_update_own" ON exercises FOR UPDATE USING (
  auth.uid() = created_by AND is_preset = FALSE
);
CREATE POLICY "exercises_delete_own" ON exercises FOR DELETE USING (
  auth.uid() = created_by AND is_preset = FALSE
);

-- routines: 自分のルーティンだけ
ALTER TABLE routines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "routines_select_own" ON routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "routines_insert_own" ON routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "routines_update_own" ON routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "routines_delete_own" ON routines FOR DELETE USING (auth.uid() = user_id);

-- routine_exercises: 自分のルーティンに属するもののみ
ALTER TABLE routine_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "routine_exercises_select_own" ON routine_exercises FOR SELECT USING (
  EXISTS (SELECT 1 FROM routines WHERE routines.id = routine_exercises.routine_id AND routines.user_id = auth.uid())
);
CREATE POLICY "routine_exercises_insert_own" ON routine_exercises FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM routines WHERE routines.id = routine_exercises.routine_id AND routines.user_id = auth.uid())
);
CREATE POLICY "routine_exercises_update_own" ON routine_exercises FOR UPDATE USING (
  EXISTS (SELECT 1 FROM routines WHERE routines.id = routine_exercises.routine_id AND routines.user_id = auth.uid())
);
CREATE POLICY "routine_exercises_delete_own" ON routine_exercises FOR DELETE USING (
  EXISTS (SELECT 1 FROM routines WHERE routines.id = routine_exercises.routine_id AND routines.user_id = auth.uid())
);

-- routine_logs: 自分のログだけ
ALTER TABLE routine_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "routine_logs_select_own" ON routine_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "routine_logs_insert_own" ON routine_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "routine_logs_update_own" ON routine_logs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "routine_logs_delete_own" ON routine_logs FOR DELETE USING (auth.uid() = user_id);

-- exercise_logs: 自分のルーティンログに属するもののみ
ALTER TABLE exercise_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "exercise_logs_select_own" ON exercise_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM routine_logs WHERE routine_logs.id = exercise_logs.routine_log_id AND routine_logs.user_id = auth.uid())
);
CREATE POLICY "exercise_logs_insert_own" ON exercise_logs FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM routine_logs WHERE routine_logs.id = exercise_logs.routine_log_id AND routine_logs.user_id = auth.uid())
);
CREATE POLICY "exercise_logs_update_own" ON exercise_logs FOR UPDATE USING (
  EXISTS (SELECT 1 FROM routine_logs WHERE routine_logs.id = exercise_logs.routine_log_id AND routine_logs.user_id = auth.uid())
);
CREATE POLICY "exercise_logs_delete_own" ON exercise_logs FOR DELETE USING (
  EXISTS (SELECT 1 FROM routine_logs WHERE routine_logs.id = exercise_logs.routine_log_id AND routine_logs.user_id = auth.uid())
);

-- ============================================
-- 4. プロフィール自動作成トリガー
-- （ユーザー登録時に自動でprofilesレコードを作成）
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', 'ユーザー'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- 5. プリセットエクササイズ（日本語）
-- ============================================

INSERT INTO exercises (name, category, description, icon, is_preset) VALUES
  -- 胸
  ('ベンチプレス', 'strength', 'バーベルを使った胸のトレーニング', '🏋️', TRUE),
  ('ダンベルフライ', 'strength', 'ダンベルを使った胸のストレッチ種目', '🦅', TRUE),
  ('腕立て伏せ', 'strength', '自重で行う胸のトレーニング', '💪', TRUE),
  ('インクラインベンチプレス', 'strength', '傾斜をつけた胸の上部トレーニング', '🏋️', TRUE),
  -- 背中
  ('デッドリフト', 'strength', 'バーベルを使った背中・全身トレーニング', '🏋️', TRUE),
  ('ラットプルダウン', 'strength', 'ケーブルを使った背中のトレーニング', '💪', TRUE),
  ('懸垂', 'strength', '自重で行う背中のトレーニング', '🔝', TRUE),
  ('ベントオーバーロウ', 'strength', 'バーベルを使った背中のトレーニング', '🏋️', TRUE),
  -- 脚
  ('スクワット', 'strength', 'バーベルを使った脚のトレーニング', '🦵', TRUE),
  ('レッグプレス', 'strength', 'マシンを使った脚のトレーニング', '🦵', TRUE),
  ('レッグカール', 'strength', 'ハムストリングスのトレーニング', '🦵', TRUE),
  ('カーフレイズ', 'strength', 'ふくらはぎのトレーニング', '🦵', TRUE),
  -- 肩
  ('ショルダープレス', 'strength', 'バーベルまたはダンベルでの肩トレーニング', '💪', TRUE),
  ('サイドレイズ', 'strength', 'ダンベルを使った肩の横部トレーニング', '💪', TRUE),
  -- 腕
  ('ダンベルカール', 'strength', 'ダンベルを使った上腕二頭筋トレーニング', '💪', TRUE),
  ('トライセプスエクステンション', 'strength', '上腕三頭筋のトレーニング', '💪', TRUE),
  -- 腹筋・体幹
  ('腹筋（クランチ）', 'strength', '基本的な腹筋トレーニング', '🔥', TRUE),
  ('プランク', 'strength', '体幹を鍛える静的トレーニング', '🔥', TRUE),
  ('レッグレイズ', 'strength', '下腹部のトレーニング', '🔥', TRUE),
  -- 有酸素
  ('ランニング', 'cardio', 'ランニング・ジョギング', '🏃', TRUE),
  ('エアロバイク', 'cardio', 'バイクマシンでの有酸素運動', '🚴', TRUE),
  ('縄跳び', 'cardio', '縄跳びでの有酸素運動', '⏭️', TRUE),
  -- ゲーム
  ('リングフィット', 'game', 'Nintendo Switch リングフィットアドベンチャー', '🎮', TRUE),
  ('フィットボクシング', 'game', 'Nintendo Switch フィットボクシング', '🥊', TRUE),
  ('Just Dance', 'game', 'ダンスゲーム', '💃', TRUE);
