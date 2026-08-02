# frozen_string_literal: true

module Types
  class ExerciseProgressPointType < BaseObject
    graphql_name "ExerciseProgressPoint"
    field :date, DateType, null: false
    field :max_weight, Float, null: false
    field :total_reps, Integer, null: false
    field :total_volume, Float, null: false, description: "kg × 回。自重種目は 0"
  end
end
