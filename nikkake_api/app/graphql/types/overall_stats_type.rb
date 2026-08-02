# frozen_string_literal: true

module Types
  class OverallStatsType < BaseObject
    graphql_name "OverallStats"
    field :total_workouts, Integer, null: false
    field :this_week_count, Integer, null: false, description: "今日を含む直近7日"
    field :total_duration_sec, Integer, null: false
    field :total_sets, Integer, null: false
  end
end
