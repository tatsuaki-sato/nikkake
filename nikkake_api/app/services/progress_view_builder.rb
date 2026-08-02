# frozen_string_literal: true

# 進捗画面ぶんを一括で組み立てる。
class ProgressViewBuilder
  View = Data.define(:overall, :streak, :daily_stats, :completed_dates, :exercises_with_logs)

  def initialize(user:, today:, range_days: 7)
    @user = user
    @today = today
    @range_days = range_days
  end

  def call
    routine_logs = @user.routine_logs.kept.to_a
    exercise_logs = @user.exercise_logs.kept.to_a

    logged_ids = exercise_logs.map(&:exercise_id).uniq
    exercises = logged_ids.empty? ? [] : Exercise.kept.where(id: logged_ids).order(:name).to_a

    View.new(
      overall: Domain::Stats.calculate_overall_stats(
        routine_logs: routine_logs, exercise_logs: exercise_logs, today: @today
      ),
      streak: Domain::Stats.calculate_streak(logs: routine_logs, today: @today),
      daily_stats: Domain::Stats.calculate_daily_stats(
        logs: routine_logs, days: @range_days, today: @today
      ),
      completed_dates: Domain::Stats.completed_dates(routine_logs),
      exercises_with_logs: exercises
    )
  end
end
