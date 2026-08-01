-- ============================================
-- nikkake - ローカルファースト化に伴うスキーマ変更
-- ============================================
--
-- 背景:
--   アプリはサインインなしで使えるようになり、端末ローカルが真実の源になった。
--   Supabaseは「サインインしたユーザーのバックアップ兼マルチデバイス同期先」に役割が変わる。
--
-- そのために必要なもの:
--   1. 全テーブルに updated_at / deleted_at
--      - updated_at: 同期の差分カーソルと衝突解決(last-write-wins)のキー
--      - deleted_at: 論理削除。物理削除だと削除が他端末へ伝播しない
--   2. クライアント生成UUIDの受け入れ（採番をサーバに任せない）
--   3. プリセット種目のIDを全プラットフォーム共通の固定値にする
--   4. RPCの廃止（同期は素のupsertで足りる）

-- ============================================
-- 1. 同期用カラムの追加
-- ============================================

ALTER TABLE exercises          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE exercises          ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE routines           ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE routines           ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE routine_exercises  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE routine_exercises  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE routine_logs       ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE routine_logs       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE exercise_logs      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE exercise_logs      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- ============================================
-- 2. ローカルファーストで必要になった列
-- ============================================

-- ルーティンの並び順をユーザーが決められるようにする
ALTER TABLE routines ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0 NOT NULL;

-- セット間の休憩秒数。ワークアウト画面のレストタイマーに使う
ALTER TABLE routine_exercises ADD COLUMN IF NOT EXISTS rest_sec INTEGER;

-- 種目ごとの推移グラフのため。
-- routine_exercises はルーティン編集のたびに作り直されるので、
-- そこ経由で辿ると編集した時点で履歴が切れてしまう。
ALTER TABLE exercise_logs ADD COLUMN IF NOT EXISTS exercise_id UUID REFERENCES exercises(id) ON DELETE SET NULL;

UPDATE exercise_logs el
SET exercise_id = re.exercise_id
FROM routine_exercises re
WHERE el.routine_exercise_id = re.id
  AND el.exercise_id IS NULL;

-- ルーティンを編集で作り直しても過去ログを残したいので、
-- 参照先が消えてもログ自体は消さない
ALTER TABLE exercise_logs DROP CONSTRAINT IF EXISTS exercise_logs_routine_exercise_id_fkey;
ALTER TABLE exercise_logs
  ADD CONSTRAINT exercise_logs_routine_exercise_id_fkey
  FOREIGN KEY (routine_exercise_id) REFERENCES routine_exercises(id) ON DELETE SET NULL;
ALTER TABLE exercise_logs ALTER COLUMN routine_exercise_id DROP NOT NULL;

-- ============================================
-- 3. updated_at 自動更新トリガー
-- ============================================
--
-- クライアントは自分で updated_at を載せてくるが、
-- サーバ側で更新された場合に差分同期から漏れないよう保険をかける。
-- クライアントが明示的に新しい値を送ってきた場合はそれを尊重する。

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.updated_at IS NULL OR NEW.updated_at <= OLD.updated_at THEN
    NEW.updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['exercises', 'routines', 'routine_exercises', 'routine_logs', 'exercise_logs']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_touch_updated_at ON %I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_touch_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION touch_updated_at()',
      t
    );
  END LOOP;
END $$;

-- ============================================
-- 4. 差分同期用インデックス
-- ============================================

CREATE INDEX IF NOT EXISTS idx_exercises_updated_at         ON exercises(updated_at);
CREATE INDEX IF NOT EXISTS idx_routines_user_updated        ON routines(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_routine_exercises_updated    ON routine_exercises(updated_at);
CREATE INDEX IF NOT EXISTS idx_routine_logs_user_updated    ON routine_logs(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_exercise_logs_updated        ON exercise_logs(updated_at);
CREATE INDEX IF NOT EXISTS idx_exercise_logs_exercise       ON exercise_logs(exercise_id);

-- ============================================
-- 5. プリセット種目のIDを固定値へ揃える
-- ============================================
--
-- 端末ごとにランダムUUIDでプリセットを作ると、同期時に同じ種目が重複する。
-- RN / Flutter / KMP の3実装すべてがこの固定IDを埋め込んでいる。
-- 変更する場合は3実装のconstantsも必ず合わせること。

-- 旧プリセット（ランダムUUID）のうち、どこからも参照されていないものを掃除する
DELETE FROM exercises e
WHERE e.is_preset = TRUE
  AND e.id NOT IN (SELECT id FROM (VALUES
    ('00000000-0000-4000-8000-000000000001'::uuid),
    ('00000000-0000-4000-8000-000000000002'::uuid),
    ('00000000-0000-4000-8000-000000000003'::uuid),
    ('00000000-0000-4000-8000-000000000004'::uuid),
    ('00000000-0000-4000-8000-000000000005'::uuid),
    ('00000000-0000-4000-8000-000000000006'::uuid),
    ('00000000-0000-4000-8000-000000000007'::uuid),
    ('00000000-0000-4000-8000-000000000008'::uuid),
    ('00000000-0000-4000-8000-000000000009'::uuid),
    ('00000000-0000-4000-8000-000000000010'::uuid),
    ('00000000-0000-4000-8000-000000000011'::uuid),
    ('00000000-0000-4000-8000-000000000012'::uuid),
    ('00000000-0000-4000-8000-000000000013'::uuid),
    ('00000000-0000-4000-8000-000000000014'::uuid),
    ('00000000-0000-4000-8000-000000000015'::uuid),
    ('00000000-0000-4000-8000-000000000016'::uuid),
    ('00000000-0000-4000-8000-000000000017'::uuid),
    ('00000000-0000-4000-8000-000000000018'::uuid),
    ('00000000-0000-4000-8000-000000000019'::uuid),
    ('00000000-0000-4000-8000-000000000020'::uuid),
    ('00000000-0000-4000-8000-000000000021'::uuid),
    ('00000000-0000-4000-8000-000000000022'::uuid),
    ('00000000-0000-4000-8000-000000000023'::uuid),
    ('00000000-0000-4000-8000-000000000024'::uuid),
    ('00000000-0000-4000-8000-000000000025'::uuid)
  ) AS fixed(id))
  AND NOT EXISTS (SELECT 1 FROM routine_exercises re WHERE re.exercise_id = e.id)
  AND NOT EXISTS (SELECT 1 FROM exercise_logs el WHERE el.exercise_id = e.id);

INSERT INTO exercises (id, name, category, description, icon, is_preset) VALUES
  ('00000000-0000-4000-8000-000000000001', 'ベンチプレス', 'strength', 'バーベルを使った胸のトレーニング', '🏋️', TRUE),
  ('00000000-0000-4000-8000-000000000002', 'ダンベルフライ', 'strength', 'ダンベルを使った胸のストレッチ種目', '🦅', TRUE),
  ('00000000-0000-4000-8000-000000000003', '腕立て伏せ', 'strength', '自重で行う胸のトレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000004', 'インクラインベンチプレス', 'strength', '傾斜をつけた胸の上部トレーニング', '🏋️', TRUE),
  ('00000000-0000-4000-8000-000000000005', 'デッドリフト', 'strength', 'バーベルを使った背中・全身トレーニング', '🏋️', TRUE),
  ('00000000-0000-4000-8000-000000000006', 'ラットプルダウン', 'strength', 'ケーブルを使った背中のトレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000007', '懸垂', 'strength', '自重で行う背中のトレーニング', '🔝', TRUE),
  ('00000000-0000-4000-8000-000000000008', 'ベントオーバーロウ', 'strength', 'バーベルを使った背中のトレーニング', '🏋️', TRUE),
  ('00000000-0000-4000-8000-000000000009', 'スクワット', 'strength', '自重またはバーベルでの脚のトレーニング', '🦵', TRUE),
  ('00000000-0000-4000-8000-000000000010', 'レッグプレス', 'strength', 'マシンを使った脚のトレーニング', '🦵', TRUE),
  ('00000000-0000-4000-8000-000000000011', 'レッグカール', 'strength', 'ハムストリングスのトレーニング', '🦵', TRUE),
  ('00000000-0000-4000-8000-000000000012', 'カーフレイズ', 'strength', 'ふくらはぎのトレーニング', '🦵', TRUE),
  ('00000000-0000-4000-8000-000000000013', 'ショルダープレス', 'strength', 'バーベルまたはダンベルでの肩トレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000014', 'サイドレイズ', 'strength', 'ダンベルを使った肩の横部トレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000015', 'ダンベルカール', 'strength', 'ダンベルを使った上腕二頭筋トレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000016', 'トライセプスエクステンション', 'strength', '上腕三頭筋のトレーニング', '💪', TRUE),
  ('00000000-0000-4000-8000-000000000017', '腹筋（クランチ）', 'strength', '基本的な腹筋トレーニング', '🔥', TRUE),
  ('00000000-0000-4000-8000-000000000018', 'プランク', 'strength', '体幹を鍛える静的トレーニング', '🔥', TRUE),
  ('00000000-0000-4000-8000-000000000019', 'レッグレイズ', 'strength', '下腹部のトレーニング', '🔥', TRUE),
  ('00000000-0000-4000-8000-000000000020', 'ランニング', 'cardio', 'ランニング・ジョギング', '🏃', TRUE),
  ('00000000-0000-4000-8000-000000000021', 'エアロバイク', 'cardio', 'バイクマシンでの有酸素運動', '🚴', TRUE),
  ('00000000-0000-4000-8000-000000000022', '縄跳び', 'cardio', '縄跳びでの有酸素運動', '⏭️', TRUE),
  ('00000000-0000-4000-8000-000000000023', 'リングフィット', 'game', 'Nintendo Switch リングフィットアドベンチャー', '🎮', TRUE),
  ('00000000-0000-4000-8000-000000000024', 'フィットボクシング', 'game', 'Nintendo Switch フィットボクシング', '🥊', TRUE),
  ('00000000-0000-4000-8000-000000000025', 'Just Dance', 'game', 'ダンスゲーム', '💃', TRUE)
ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name,
      category = EXCLUDED.category,
      description = EXCLUDED.description,
      icon = EXCLUDED.icon,
      is_preset = TRUE;

-- ============================================
-- 6. RLSの調整
-- ============================================
--
-- 論理削除に切り替えたため、クライアントはDELETEを一切発行しない。
-- 代わりに deleted_at を立てるUPDATEが飛ぶので、既存のUPDATEポリシーで足りる。
-- INSERT時にRLSのWITH CHECKを通すため、UPDATEポリシーにもWITH CHECKを明示しておく。

DROP POLICY IF EXISTS "routines_update_own" ON routines;
CREATE POLICY "routines_update_own" ON routines FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "routine_logs_update_own" ON routine_logs;
CREATE POLICY "routine_logs_update_own" ON routine_logs FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- カスタム種目はサインイン前に作られている場合 created_by が NULL のまま同期されてくる。
-- 同期処理が created_by を埋めるので、NULLのINSERTは許可しない方針を維持しつつ
-- 自分のものとして入れ直せるようにする。
DROP POLICY IF EXISTS "exercises_update_own" ON exercises;
CREATE POLICY "exercises_update_own" ON exercises FOR UPDATE
  USING (created_by = auth.uid() AND is_preset = FALSE)
  WITH CHECK (created_by = auth.uid() AND is_preset = FALSE);

-- ============================================
-- 7. 不要になったRPCの削除
-- ============================================
--
-- ワークアウト保存はローカルで完結し、同期は素のupsertで行うため使わなくなった。

DROP FUNCTION IF EXISTS save_workout_log(UUID, INTEGER, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS get_last_workout_logs(UUID);
