# frozen_string_literal: true

module Types
  class WorkoutSessionExerciseType < BaseObject
    graphql_name "WorkoutSessionExercise"
    field :routine_exercise_id, ID, null: false
    field :exercise, ExerciseType, null: false
    field :target_sets, Integer, null: false
    field :target_reps, Integer
    field :target_weight, Float
    field :target_duration_sec, Integer, description: "非 null なら時間計測の種目"
    field :rest_sec, Integer, null: false
    field :previous_sets, [ RecordedSetType ], null: false
    field :previous_label, String
  end
end
