# frozen_string_literal: true

module Types
  class RoutineType < BaseObject
    graphql_name "Routine"
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String
    field :color, String, null: false
    field :icon, String, null: false
    field :frequency_type, FrequencyTypeType, null: false
    field :frequency_value, Integer, null: false
    field :frequency_days, [ Integer ], null: false, description: "日=0 .. 土=6"
    field :preferred_time, String, description: "通知を出す端末ローカルの時刻（HH:MM）。null なら通知しない"
    field :is_active, Boolean, null: false
    field :sort_order, Integer, null: false
    field :lock_version, Integer, null: false, description: "楽観ロック用。updateRoutine に必ず渡す"
    field :routine_exercises, [ RoutineExerciseType ], null: false
    field :updated_at, DateTimeType, null: false
    field :deleted_at, DateTimeType

    def preferred_time
      object.preferred_time&.strftime("%H:%M")
    end

    def routine_exercises
      dataloader.with(Sources::KeptByForeignKey, RoutineExercise, :routine_id)
                .load(object.id).sort_by(&:sort_order)
    end
  end
end
