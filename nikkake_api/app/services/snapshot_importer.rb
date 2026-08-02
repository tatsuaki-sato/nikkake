# frozen_string_literal: true

# 端末ローカルのデータをまるごとサーバへ取り込む。
#
# 遅延登録の本体。初回起動時にクライアントはネットワーク無しでローカルに
# シードして画面を出し、あとからこれを呼んでサーバへ登録する。
# そうしないと、アプリを入れた直後に圏外だと1歩も動かない。
#
# ID はクライアント生成なので、同じスナップショットを何度送っても
# ON CONFLICT DO NOTHING で吸収され、二重登録されない。
class SnapshotImporter
  Counts = Data.define(:routines, :exercises, :routine_logs, :exercise_logs)

  def initialize(user:, payload:)
    @user = user
    @payload = payload
  end

  def call
    ActiveRecord::Base.transaction do
      import_exercises
      import_routines
      import_routine_exercises
      import_routine_logs
      import_exercise_logs
    end

    Counts.new(
      routines: @user.routines.kept.count,
      exercises: Exercise.kept.visible_to(@user).count,
      routine_logs: @user.routine_logs.kept.count,
      exercise_logs: @user.exercise_logs.kept.count
    )
  end

  private

  def rows_for(key) = Array(@payload[key])

  def insert(klass, rows)
    return if rows.empty?

    klass.insert_all(rows, unique_by: :id)
  end

  # プリセット種目はサーバ側の共有マスタなので取り込まない
  def import_exercises
    rows = rows_for(:exercises).map do |e|
      {
        id: e[:id], name: e[:name], category: e[:category],
        description: e[:description], icon: e[:icon],
        is_preset: false, created_by_id: @user.id,
        deleted_at: e[:deleted_at],
        created_at: e[:created_at], updated_at: e[:updated_at]
      }
    end
    insert(Exercise, rows)
  end

  def import_routines
    rows = rows_for(:routines).map do |r|
      {
        id: r[:id], user_id: @user.id, name: r[:name], description: r[:description],
        color: r[:color], icon: r[:icon],
        frequency_type: r[:frequency_type], frequency_value: r[:frequency_value],
        frequency_days: r[:frequency_days] || [],
        is_active: r.fetch(:is_active, true), sort_order: r[:sort_order] || 0,
        deleted_at: r[:deleted_at],
        created_at: r[:created_at], updated_at: r[:updated_at]
      }
    end
    insert(Routine, rows)
  end

  def import_routine_exercises
    rows = rows_for(:routine_exercises).map do |re|
      {
        id: re[:id], user_id: @user.id, routine_id: re[:routine_id], exercise_id: re[:exercise_id],
        sort_order: re[:sort_order] || 0, target_sets: re[:target_sets] || 3,
        target_reps: re[:target_reps], target_weight: re[:target_weight],
        target_duration_sec: re[:target_duration_sec], rest_sec: re[:rest_sec],
        deleted_at: re[:deleted_at],
        created_at: re[:created_at], updated_at: re[:updated_at]
      }
    end
    insert(RoutineExercise, rows)
  end

  def import_routine_logs
    rows = rows_for(:routine_logs).map do |l|
      {
        id: l[:id], user_id: @user.id, routine_id: l[:routine_id],
        log_date: l[:log_date], status: l[:status], duration_sec: l[:duration_sec],
        started_at: l[:started_at], completed_at: l[:completed_at],
        deleted_at: l[:deleted_at],
        created_at: l[:created_at], updated_at: l[:updated_at]
      }
    end
    insert(RoutineLog, rows)
  end

  def import_exercise_logs
    rows = rows_for(:exercise_logs).map do |l|
      {
        id: l[:id], user_id: @user.id, routine_log_id: l[:routine_log_id],
        routine_exercise_id: l[:routine_exercise_id], exercise_id: l[:exercise_id],
        set_number: l[:set_number], actual_reps: l[:actual_reps],
        actual_weight: l[:actual_weight], actual_duration_sec: l[:actual_duration_sec],
        deleted_at: l[:deleted_at],
        created_at: l[:created_at], updated_at: l[:updated_at]
      }
    end
    insert(ExerciseLog, rows)
  end
end
