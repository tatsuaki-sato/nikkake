# frozen_string_literal: true

module Types
  class HomeViewType < BaseObject
    graphql_name "HomeView"
    field :today, DateType, null: false
    field :streak, StreakType, null: false
    field :due, [ TodayRoutineType ], null: false, description: "今日やる分"
    field :not_scheduled, [ TodayRoutineType ], null: false, description: "今日は予定なし"
    field :completed, [ TodayRoutineType ], null: false
  end
end
