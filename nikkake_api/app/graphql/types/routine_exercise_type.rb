# frozen_string_literal: true

module Types
  class RoutineExerciseType < BaseObject
    graphql_name "RoutineExercise"
    field :id, ID, null: false
    field :routine_id, ID, null: false
    field :exercise, ExerciseType, null: false
    field :sort_order, Integer, null: false
    field :target_sets, Integer, null: false
    field :target_reps, Integer
    field :target_weight, Float
    field :target_duration_sec, Integer
    field :rest_sec, Integer
    field :updated_at, DateTimeType, null: false
    field :deleted_at, DateTimeType

    def exercise
      dataloader.with(Sources::RecordById, Exercise).load(object.exercise_id)
    end
  end
end
