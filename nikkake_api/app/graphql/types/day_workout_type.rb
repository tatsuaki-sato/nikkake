# frozen_string_literal: true

module Types
  class DayWorkoutType < BaseObject
    graphql_name "DayWorkout"
    field :routine_log_id, ID, null: false
    field :routine_name, String, null: false,
          description: "実施時点のルーティン名。ルーティンを消してもここには残る"
    field :status, LogStatusType, null: false
    field :duration_sec, Integer
    field :exercises, [ DayExerciseSummaryType ], null: false
  end
end
