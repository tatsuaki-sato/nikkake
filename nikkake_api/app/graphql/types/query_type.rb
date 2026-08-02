# frozen_string_literal: true

module Types
  # 「画面 = クエリ1本」。集計済みのビュー型を返す。
  #
  # today / timeZone を必須引数にしているのは意図的。サーバが Date.today を
  # 使うと日本の朝8時が UTC では前日23時なので即座に1日ずれ、
  # ストリークが1日ずれるという最も致命的なバグになる。
  class QueryType < BaseObject
    graphql_name "Query"

    field :home, HomeViewType, null: false do
      argument :today, DateType
      argument :time_zone, String
    end

    field :routines, [ RoutineType ], null: false do
      argument :include_inactive, Boolean, required: false, default_value: true
    end

    field :routine, RoutineType do
      argument :id, ID
    end

    field :exercises, [ ExerciseType ], null: false

    field :workout_session, WorkoutSessionType, null: false do
      argument :routine_id, ID
    end

    field :progress, ProgressViewType, null: false do
      argument :today, DateType
      argument :time_zone, String
      argument :range_days, Integer, required: false, default_value: 7
    end

    field :exercise_progress, [ ExerciseProgressPointType ], null: false do
      argument :exercise_id, ID
      argument :limit, Integer, required: false, default_value: 8
    end

    field :viewer, ViewerType, null: false

    field :changes, ChangeSetType, null: false do
      argument :since, DateTimeType, required: false
    end

    def home(today:, time_zone:)
      HomeViewBuilder.new(user: current_user, today: today).call
    end

    def routines(include_inactive:)
      scope = current_user.routines.kept.ordered
      include_inactive ? scope : scope.where(is_active: true)
    end

    def routine(id:)
      current_user.routines.kept.find_by(id: id)
    end

    def exercises
      Exercise.kept.visible_to(current_user).order(:category, :name)
    end

    def workout_session(routine_id:)
      routine = current_user.routines.kept.find_by(id: routine_id)
      raise not_found unless routine

      WorkoutSessionBuilder.new(user: current_user, routine: routine).call
    end

    def progress(today:, time_zone:, range_days:)
      ProgressViewBuilder.new(user: current_user, today: today, range_days: range_days).call
    end

    def exercise_progress(exercise_id:, limit:)
      Domain::Stats.calculate_exercise_progress(
        exercise_id: exercise_id,
        routine_logs: current_user.routine_logs.kept.to_a,
        exercise_logs: current_user.exercise_logs.kept.to_a
      ).last(limit)
    end

    def viewer = current_user

    def changes(since: nil)
      {
        cursor: Time.current,
        exercises: Exercise.visible_to(current_user).changed_since(since),
        routines: current_user.routines.changed_since(since),
        routine_exercises: current_user.routine_exercises.changed_since(since),
        routine_logs: current_user.routine_logs.changed_since(since),
        exercise_logs: current_user.exercise_logs.changed_since(since)
      }
    end

    private

    # 所有者スコープから辿ることを徹底する。
    # 存在しない ID と他人の ID を同じ NOT_FOUND にするのは、
    # ID の存在有無を漏らさないため。
    def current_user
      context[:current_user] or
        raise GraphQL::ExecutionError.new("認証が必要です", extensions: { "code" => "UNAUTHENTICATED" })
    end

    def not_found
      GraphQL::ExecutionError.new("見つかりません", extensions: { "code" => "NOT_FOUND" })
    end
  end
end
