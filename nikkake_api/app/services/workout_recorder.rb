# frozen_string_literal: true

# ワークアウト1回分の保存。
#
# 冪等性の主機構はクライアント生成 UUID の主キー衝突。
# 再送しても同じ id なので二重登録されず、insert_all の ON CONFLICT で吸収される。
#
# status はクライアントに送らせない。完了セット数と total_sets からサーバが判定する。
class WorkoutRecorder
  Result = Data.define(:routine_log, :summary, :streak)
  Summary = Data.define(
    :routine_log_id, :routine_name, :duration_sec,
    :completed_sets, :total_sets, :total_volume, :status
  )

  def initialize(user:, input:)
    @user = user
    @input = input
  end

  def call
    # 削除済みのルーティンでも記録は受け付ける。
    # オフラインキューが削除済みルーティンへの記録を持ちうるため、
    # ここで弾くと永久に送信できないレコードが生まれる。
    routine = @user.routines.find_by(id: @input[:routine_id])
    raise ActiveRecord::RecordNotFound, "ルーティンが見つかりません" if routine.nil?

    completed = @input[:sets].size
    total = [ @input[:total_sets].to_i, completed ].max
    status = resolve_status(completed, total)
    now = Time.current

    ActiveRecord::Base.transaction do
      RoutineLog.insert_all(
        [ {
          id: @input[:id],
          user_id: @user.id,
          routine_id: routine.id,
          log_date: @input[:log_date],
          status: status,
          duration_sec: @input[:duration_sec],
          started_at: @input[:started_at],
          completed_at: now,
          client_time_zone: @input[:time_zone],
          client_utc_offset_minutes: utc_offset_minutes(@input[:time_zone]),
          created_at: now,
          updated_at: now
        } ],
        unique_by: :id
      )

      rows = @input[:sets].map do |s|
        {
          id: s[:id],
          user_id: @user.id,
          routine_log_id: @input[:id],
          routine_exercise_id: s[:routine_exercise_id],
          exercise_id: s[:exercise_id],
          set_number: s[:set_number],
          actual_reps: s[:actual_reps],
          actual_weight: s[:actual_weight],
          actual_duration_sec: s[:actual_duration_sec],
          created_at: now,
          updated_at: now
        }
      end
      ExerciseLog.insert_all(rows, unique_by: :id) if rows.any?
    end

    log = @user.routine_logs.find(@input[:id])
    volume = Domain::Stats.calculate_volume(log.exercise_logs.kept.to_a)

    Result.new(
      routine_log: log,
      summary: Summary.new(
        routine_log_id: log.id,
        routine_name: routine.name,
        duration_sec: log.duration_sec.to_i,
        completed_sets: log.exercise_logs.kept.count,
        total_sets: total,
        total_volume: volume,
        status: log.status
      ),
      streak: Domain::Stats.calculate_streak(
        logs: @user.routine_logs.kept.to_a,
        today: Domain::DateUtil.parse_date(@input[:log_date])
      )
    )
  end

  private

  def resolve_status(completed, total)
    return "skipped" if completed.zero?
    return "completed" if completed >= total

    "partial"
  end

  def utc_offset_minutes(zone_name)
    zone = ActiveSupport::TimeZone[zone_name.to_s]
    zone && (zone.utc_offset / 60)
  end
end
