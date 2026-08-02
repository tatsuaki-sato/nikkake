# frozen_string_literal: true

module Mutations
  module RoutineValidation
    def validate(name:, exercises:, frequency_type:, frequency_days:)
      return user_error("ルーティン名を入力してください", code: "VALIDATION", path: [ "name" ]) if name.blank?
      return user_error("種目を1つ以上追加してください", code: "VALIDATION", path: [ "exercises" ]) if exercises.blank?

      if frequency_type == "weekly" && Array(frequency_days).empty?
        return user_error("曜日を1つ以上選んでください", code: "VALIDATION", path: [ "frequencyDays" ])
      end

      nil
    end
  end
end
