# frozen_string_literal: true

module Types
  class ViewerType < BaseObject
    graphql_name "Viewer"
    field :id, ID, null: false
    field :email, String, description: "匿名のうちは null"
    field :is_anonymous, Boolean, null: false
    field :email_verified, Boolean, null: false
    field :storage_mode, StorageModeType, null: false
    field :counts, DataCountsType, null: false
    field :last_synced_at, DateTimeType

    def is_anonymous = object.anonymous?
    def email_verified = object.email_verified?
    def storage_mode = "CLOUD"
    def last_synced_at = object.last_seen_at

    def counts
      {
        routines: object.routines.kept.count,
        exercises: Exercise.kept.visible_to(object).count,
        routine_logs: object.routine_logs.kept.count,
        exercise_logs: object.exercise_logs.kept.count
      }
    end
  end
end
