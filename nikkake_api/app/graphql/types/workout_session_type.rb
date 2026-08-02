# frozen_string_literal: true

module Types
  class WorkoutSessionType < BaseObject
    graphql_name "WorkoutSession"
    field :routine, RoutineType, null: false
    field :exercises, [ WorkoutSessionExerciseType ], null: false
  end
end
