# frozen_string_literal: true

module Types
  class DataCountsType < BaseObject
    graphql_name "DataCounts"
    field :routines, Integer, null: false
    field :exercises, Integer, null: false
    field :routine_logs, Integer, null: false
    field :exercise_logs, Integer, null: false
  end
end
