# frozen_string_literal: true

module Types
  class RoutineExerciseInput < BaseInputObject
    graphql_name "RoutineExerciseInput"
    argument :id, ID
    argument :exercise_id, ID
    argument :target_sets, Integer
    argument :target_reps, Integer, required: false
    argument :target_weight, Float, required: false
    argument :target_duration_sec, Integer, required: false
    argument :rest_sec, Integer, required: false
  end
end
