# frozen_string_literal: true

module Types
  class RecordedSetType < BaseObject
    graphql_name "RecordedSet"
    field :set_number, Integer, null: false
    field :reps, Integer
    field :weight, Float
    field :duration_sec, Integer
  end
end
