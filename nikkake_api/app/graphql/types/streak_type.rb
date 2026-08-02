# frozen_string_literal: true

module Types
  class StreakType < BaseObject
    graphql_name "Streak"
    field :current, Integer, null: false, description: "最終実施日が今日か昨日なら継続中"
    field :longest, Integer, null: false
    field :last_completed_date, DateType
  end
end
