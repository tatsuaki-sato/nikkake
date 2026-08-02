# frozen_string_literal: true

module Types
  class WorkoutSummaryType < BaseObject
    graphql_name "WorkoutSummary"
    field :routine_log_id, ID, null: false
    field :routine_name, String, null: false
    field :duration_sec, Integer, null: false
    field :completed_sets, Integer, null: false
    field :total_sets, Integer, null: false
    field :total_volume, Float, null: false
    field :status, LogStatusType, null: false
  end
end
