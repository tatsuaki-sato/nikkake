# frozen_string_literal: true

module Mutations
  module RoutineValidation
    PREFERRED_TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

    def validate(name:, exercises:, frequency_type:, frequency_days:, preferred_time: nil)
      return user_error("ルーティン名を入力してください", code: "VALIDATION", path: [ "name" ]) if name.blank?
      return user_error("種目を1つ以上追加してください", code: "VALIDATION", path: [ "exercises" ]) if exercises.blank?

      if frequency_type == "weekly" && Array(frequency_days).empty?
        return user_error("曜日を1つ以上選んでください", code: "VALIDATION", path: [ "frequencyDays" ])
      end

      if preferred_time.present? && !preferred_time.match?(PREFERRED_TIME)
        return user_error("通知の時刻は HH:MM で指定してください", code: "VALIDATION", path: [ "preferredTime" ])
      end

      nil
    end
  end
end
