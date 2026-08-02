# frozen_string_literal: true

module Types
  class ExerciseCategoryType < BaseEnum
    graphql_name "ExerciseCategory"
    value "STRENGTH", value: "strength"
    value "CARDIO",   value: "cardio"
    value "GAME",     value: "game"
    value "CUSTOM",   value: "custom"
  end
end
