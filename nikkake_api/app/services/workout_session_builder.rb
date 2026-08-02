# frozen_string_literal: true

# ワークアウト実行に必要なもの一式。
# 「前回の記録」もサーバが解決して返すので、クライアントは表示するだけでよい。
class WorkoutSessionBuilder
  DEFAULT_REST_SEC = 60

  Entry = Data.define(
    :routine_exercise_id, :exercise, :target_sets, :target_reps, :target_weight,
    :target_duration_sec, :rest_sec, :previous_sets, :previous_label
  )
  Session = Data.define(:routine, :exercises)
  PreviousSet = Data.define(:set_number, :reps, :weight, :duration_sec)

  def initialize(user:, routine:)
    @user = user
    @routine = routine
  end

  def call
    links = @routine.routine_exercises.kept.ordered.includes(:exercise).to_a
    previous = last_sets_by_exercise

    entries = links.map do |link|
      sets = previous[link.exercise_id] || []
      Entry.new(
        routine_exercise_id: link.id,
        exercise: link.exercise,
        target_sets: link.target_sets,
        target_reps: link.target_reps,
        target_weight: link.target_weight,
        target_duration_sec: link.target_duration_sec,
        rest_sec: link.rest_sec || DEFAULT_REST_SEC,
        previous_sets: sets,
        previous_label: sets.empty? ? nil : Domain::Stats.format_previous_sets(sets)
      )
    end

    Session.new(routine: @routine, exercises: entries)
  end

  private

  # 直近1回のワークアウトの実績。次回の初期値になる
  def last_sets_by_exercise
    latest = @user.routine_logs.kept.did_workout
                  .where(routine_id: @routine.id)
                  .order(Arel.sql("COALESCE(started_at, created_at) DESC"))
                  .first
    return {} if latest.nil?

    latest.exercise_logs.kept.order(:set_number).group_by(&:exercise_id).transform_values do |logs|
      logs.map do
        PreviousSet.new(
          set_number: _1.set_number,
          reps: _1.actual_reps,
          weight: _1.actual_weight,
          duration_sec: _1.actual_duration_sec
        )
      end
    end
  end
end
