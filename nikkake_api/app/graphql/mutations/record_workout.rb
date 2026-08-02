# frozen_string_literal: true

module Mutations
  class RecordWorkout < BaseMutation
    graphql_name "RecordWorkout"
    argument :id, ID
    argument :routine_id, ID
    argument :log_date, Types::DateType, description: "端末TZで決めた日付"
    argument :time_zone, String
    argument :started_at, Types::DateTimeType
    argument :duration_sec, Integer, required: false
    argument :total_sets, Integer
    argument :sets, [ Types::RecordedSetInput ]
    argument :client_mutation_id, String, required: false

    field :routine_log, Types::RoutineLogType
    field :summary, Types::WorkoutSummaryType
    field :streak, Types::StreakType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(**args)
      result = WorkoutRecorder.new(
        user: current_user,
        input: args.merge(sets: args[:sets].map(&:to_h))
      ).call

      ok(routine_log: result.routine_log, summary: result.summary, streak: result.streak)
    rescue ActiveRecord::RecordNotFound
      ng(user_error("ルーティンが見つかりません", code: "NOT_FOUND"))
    end
  end
end
