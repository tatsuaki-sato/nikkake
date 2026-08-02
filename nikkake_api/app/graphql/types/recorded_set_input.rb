# frozen_string_literal: true

module Types
  class RecordedSetInput < BaseInputObject
    graphql_name "RecordedSetInput"
    argument :id, ID
    argument :routine_exercise_id, ID, required: false
    argument :exercise_id, ID
    argument :set_number, Integer
    argument :actual_reps, Integer, required: false
    argument :actual_weight, Float, required: false
    argument :actual_duration_sec, Integer, required: false
  end
end
