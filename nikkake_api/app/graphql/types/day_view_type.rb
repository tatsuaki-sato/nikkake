# frozen_string_literal: true

module Types
  class DayViewType < BaseObject
    graphql_name "DayView"
    field :date, DateType, null: false
    field :workouts, [ DayWorkoutType ], null: false,
          description: "その日に記録したワークアウト。記録が無ければ空"
  end
end
