# frozen_string_literal: true

module Types
  class ExerciseLogType < BaseObject
    graphql_name "ExerciseLog"
    field :id, ID, null: false
    field :routine_log_id, ID, null: false
    field :exercise_id, ID, null: false
    field :set_number, Integer, null: false
    field :actual_reps, Integer
    field :actual_weight, Float
    field :actual_duration_sec, Integer
    field :updated_at, DateTimeType, null: false
    field :deleted_at, DateTimeType
  end
end
