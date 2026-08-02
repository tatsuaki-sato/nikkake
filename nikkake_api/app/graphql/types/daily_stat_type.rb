# frozen_string_literal: true

module Types
  class DailyStatType < BaseObject
    graphql_name "DailyStat"
    field :date, DateType, null: false
    field :completed_count, Integer, null: false, description: "skipped 以外の件数"
    field :total_count, Integer, null: false
  end
end
