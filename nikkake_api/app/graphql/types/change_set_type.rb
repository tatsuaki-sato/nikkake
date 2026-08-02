# frozen_string_literal: true

module Types
  class ChangeSetType < BaseObject
    graphql_name "ChangeSet"
    field :cursor, DateTimeType, null: false
    field :exercises, [ ExerciseType ], null: false
    field :routines, [ RoutineType ], null: false
    field :routine_exercises, [ RoutineExerciseType ], null: false
    field :routine_logs, [ RoutineLogType ], null: false
    field :exercise_logs, [ ExerciseLogType ], null: false
  end
end
