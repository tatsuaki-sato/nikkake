-- ============================================
-- nikkake - ワークアウト履歴と保存の共通化RPC
-- ============================================

-- 1. ワークアウト結果のトランザクション保存
CREATE OR REPLACE FUNCTION save_workout_log(
  p_routine_id UUID,
  p_duration_sec INTEGER,
  p_status TEXT,
  p_notes TEXT,
  p_exercise_logs JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_log_id UUID;
  v_result JSONB;
BEGIN
  -- 実行ユーザーIDの取得（セッションから）
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. routine_logs の作成
  INSERT INTO routine_logs (
    routine_id,
    user_id,
    log_date,
    status,
    duration_sec,
    notes,
    completed_at
  ) VALUES (
    p_routine_id,
    v_user_id,
    CURRENT_DATE,
    p_status,
    p_duration_sec,
    p_notes,
    NOW()
  ) RETURNING id INTO v_log_id;

  -- 2. JSONBからの exercise_logs の作成
  -- p_exercise_logs は以下のような配列を想定
  -- [ { "routine_exercise_id": "...", "set_number": 1, "actual_reps": 10, "actual_weight": 50.0, "actual_duration_sec": null, "notes": null } ]
  IF jsonb_array_length(p_exercise_logs) > 0 THEN
    INSERT INTO exercise_logs (
      routine_log_id,
      routine_exercise_id,
      set_number,
      actual_reps,
      actual_weight,
      actual_duration_sec,
      notes
    )
    SELECT
      v_log_id,
      (value->>'routine_exercise_id')::UUID,
      (value->>'set_number')::INTEGER,
      (value->>'actual_reps')::INTEGER,
      (value->>'actual_weight')::REAL,
      (value->>'actual_duration_sec')::INTEGER,
      value->>'notes'
    FROM jsonb_array_elements(p_exercise_logs);
  END IF;

  -- 成功結果を返す
  v_result := jsonb_build_object(
    'success', true,
    'routine_log_id', v_log_id
  );
  
  RETURN v_result;
END;
$$;


-- 2. 前回ワークアウトの実績取得
CREATE OR REPLACE FUNCTION get_last_workout_logs(
  p_routine_id UUID
)
RETURNS TABLE (
  routine_exercise_id UUID,
  set_number INTEGER,
  actual_reps INTEGER,
  actual_weight REAL,
  actual_duration_sec INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_last_log_id UUID;
BEGIN
  v_user_id := auth.uid();

  -- 最も新しい完了済みのワークアウトロギングIDを取得
  SELECT id INTO v_last_log_id
  FROM routine_logs
  WHERE routine_id = p_routine_id
    AND user_id = v_user_id
    AND status = 'completed'
  ORDER BY log_date DESC, created_at DESC
  LIMIT 1;

  -- 該当するログがあればその exercise_logs を返す
  IF v_last_log_id IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      el.routine_exercise_id,
      el.set_number,
      el.actual_reps,
      el.actual_weight,
      el.actual_duration_sec
    FROM exercise_logs el
    WHERE el.routine_log_id = v_last_log_id
    ORDER BY el.routine_exercise_id, el.set_number;
  END IF;
END;
$$;
