# frozen_string_literal: true

# 進捗カレンダーで日をタップしたときの、その日のワークアウト内容を組み立てる。
#
# date は必ず呼び出し側（＝クライアントが端末のタイムゾーンで決めて送った値）から
# 受け取る。ここで求めるとタイムゾーンで1日ずれる。
class DayViewBuilder
  View = Data.define(:date, :workouts)
  Workout = Data.define(:routine_log_id, :routine_name, :status, :duration_sec, :exercises)
  ExerciseSummary = Data.define(:exercise_name, :sets_label)

  def initialize(user:, date:)
    @user = user
    @date = date
  end

  def call
    logs = @user.routine_logs.kept.where(log_date: @date)
                .includes(:routine, exercise_logs: :exercise)
                .order(:created_at)

    View.new(date: @date, workouts: logs.map { build_workout(_1) })
  end

  private

  def build_workout(log)
    exercises = log.exercise_logs
                   .reject(&:deleted?)
                   .group_by(&:exercise)
                   .map { |exercise, sets| build_exercise(exercise, sets) }

    Workout.new(
      routine_log_id: log.id,
      routine_name: log.routine.name,
      status: log.status,
      duration_sec: log.duration_sec,
      exercises: exercises
    )
  end

  def build_exercise(exercise, sets)
    ordered = sets.sort_by(&:set_number).map do |set|
      { duration_sec: set.actual_duration_sec, weight: set.actual_weight, reps: set.actual_reps }
    end

    ExerciseSummary.new(
      exercise_name: exercise.name,
      # 文言はサーバに寄せる。「前回: …」と同じ整形を使う
      sets_label: ordered.empty? ? nil : Domain::Stats.format_previous_sets(ordered)
    )
  end
end
