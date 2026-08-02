# frozen_string_literal: true

# Rails 外（純粋な rspec）からも読めるよう、依存を明示しておく
require "date"

module Domain
  # 日付と表示フォーマット。
  #
  # ActiveRecord に一切依存しない純粋関数だけを置く。
  # packages/contract/domain_cases.json を TypeScript / Dart / Kotlin のテストと
  # 共有しているので、境界条件は移植元（nikkake_react_native/src/lib/utils.ts）を
  # そのまま写している。挙動を変えるときは4実装すべてを同時に直すこと。
  #
  # 「今日」をここで求める関数は意図的に置いていない。
  # サーバが Date.today を使うと、日本の朝8時が UTC では前日23時なので1日ずれる。
  # 日付は必ずクライアントが決めて送る（spec/architecture_spec.rb が強制）。
  module DateUtil
    DAY_NAMES = %w[日 月 火 水 木 金 土].freeze

    module_function

    # 'YYYY-MM-DD' -> Date
    def parse_date(value)
      value.is_a?(Date) ? value : Date.parse(value)
    end

    # Date -> 'YYYY-MM-DD'
    def format_date(date)
      date.strftime("%Y-%m-%d")
    end

    # 日付単位の差。DST の23時間・25時間の日があっても丸めで吸収される
    def days_between(from, to)
      (parse_date(to) - parse_date(from)).to_i
    end

    def add_days(date, days)
      parse_date(date) + days
    end

    # DBは 日=0..土=6 で曜日を持つ。Ruby の Date#wday も同じなので変換不要
    def weekday(date)
      parse_date(date).wday
    end

    # 秒 -> "1:05" / "1:02:05"。nil は "--:--"
    def format_duration(seconds)
      return "--:--" if seconds.nil?

      total = [ seconds.to_i, 0 ].max
      h = total / 3600
      m = (total % 3600) / 60
      s = total % 60

      h.positive? ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
    end

    # kg -> "60 kg" / "62.5 kg"。nil は "-- kg"。小数第1位まで、.0 は省く
    def format_weight(weight)
      return "-- kg" if weight.nil?

      rounded = weight.to_f.round(1)
      text = (rounded % 1).zero? ? rounded.to_i.to_s : rounded.to_s
      "#{text} kg"
    end

    def greeting_for_hour(hour)
      case hour
      when 0...5  then "おつかれさま"
      when 5...12 then "おはよう！"
      when 12...18 then "こんにちは！"
      else "こんばんは！"
      end
    end
  end
end
