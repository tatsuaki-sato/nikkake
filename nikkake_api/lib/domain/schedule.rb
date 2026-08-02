# frozen_string_literal: true

require_relative "date_util"

module Domain
  # ルーティンの実施予定の判定。
  # 移植元: nikkake_react_native/src/lib/utils.ts の isRoutineDueToday / formatFrequency
  module Schedule
    module_function

    # そのルーティンを今日やる予定かどうか。
    # 「今日もう終わったか」は別で判定するので、ここでは予定だけを見る。
    #
    # routine  : is_active / frequency_type / frequency_value / frequency_days に応答するもの
    # last_log : nil または log_date を持つもの（skipped を除いた最新の実施記録）
    # today    : Date（★クライアントが端末TZで決めて送ってきた値）
    def due_today?(routine:, last_log:, today:)
      return false unless routine.is_active

      case routine.frequency_type
      when "daily"
        true

      when "weekly"
        days = routine.frequency_days || []
        # 曜日が未設定なら毎日扱い
        return true if days.empty?

        days.include?(DateUtil.weekday(today))

      when "every_n_days"
        # 一度も実施していなければ今日から始められる
        return true if last_log.nil?

        interval = [ 1, routine.frequency_value.to_i ].max
        DateUtil.days_between(last_log.log_date, today) >= interval

      else
        false
      end
    end

    # 「毎日」「3日ごと」「月・水」。
    # 文言をサーバに寄せることで、4クライアントで表記がズレるのを防ぐ。
    def frequency_label(routine)
      case routine.frequency_type
      when "daily"
        "毎日"
      when "every_n_days"
        routine.frequency_value.to_i <= 1 ? "毎日" : "#{routine.frequency_value}日ごと"
      when "weekly"
        days = routine.frequency_days || []
        return "毎日" if days.empty?

        days.sort.map { DateUtil::DAY_NAMES[_1] }.join("・")
      else
        ""
      end
    end
  end
end
