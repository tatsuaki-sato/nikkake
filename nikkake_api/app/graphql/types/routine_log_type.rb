# frozen_string_literal: true

module Types
  class RoutineLogType < BaseObject
    graphql_name "RoutineLog"
    field :id, ID, null: false
    field :routine_id, ID, null: false
    field :log_date, DateType, null: false
    field :status, LogStatusType, null: false
    field :duration_sec, Integer
    field :started_at, DateTimeType
    field :completed_at, DateTimeType
    field :exercise_logs, [ ExerciseLogType ], null: false
    field :updated_at, DateTimeType, null: false
    field :deleted_at, DateTimeType

    def exercise_logs
      dataloader.with(Sources::KeptByForeignKey, ExerciseLog, :routine_log_id).load(object.id)
    end
  end
end
