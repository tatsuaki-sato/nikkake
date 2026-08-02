# frozen_string_literal: true

module Types
  class ExerciseType < BaseObject
    graphql_name "Exercise"
    field :id, ID, null: false
    field :name, String, null: false
    field :category, ExerciseCategoryType, null: false
    field :description, String
    field :icon, String
    field :is_preset, Boolean, null: false
    field :updated_at, DateTimeType, null: false
    field :deleted_at, DateTimeType
  end
end
