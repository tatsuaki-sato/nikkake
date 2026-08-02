# frozen_string_literal: true

module Types
  class ProgressViewType < BaseObject
    graphql_name "ProgressView"
    field :overall, OverallStatsType, null: false
    field :streak, StreakType, null: false
    field :daily_stats, [ DailyStatType ], null: false
    field :completed_dates, [ DateType ], null: false
    field :exercises_with_logs, [ ExerciseType ], null: false
  end
end
