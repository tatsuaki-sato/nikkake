# frozen_string_literal: true

module Mutations
  module RoutineArguments
    def self.included(base)
      base.argument :name, String
      base.argument :description, String, required: false
      base.argument :icon, String
      base.argument :color, String
      base.argument :frequency_type, Types::FrequencyTypeType
      base.argument :frequency_value, Integer, required: false, default_value: 1
      base.argument :frequency_days, [ Integer ], required: false, default_value: []
      base.argument :exercises, [ Types::RoutineExerciseInput ]
      base.argument :client_mutation_id, String, required: false

      base.field :routine, Types::RoutineType
      base.field :user_errors, [ Types::UserErrorType ], null: false
    end
  end

  # 入力の検証。文言は docs/FEATURES.md が仕様として定めている
end
