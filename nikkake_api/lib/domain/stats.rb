# frozen_string_literal: true

require_relative "date_util"

module Domain
  # 進捗まわりの集計。
  # 移植元: nikkake_react_native/src/lib/stats.ts
  #
  # 引数は ActiveRecord のレコードでも Struct でも動くよう、
  # 必要なメソッド（log_date / status など）にだけ依存させている。
  # そうしないと packages/contract/domain_cases.json による一致テストが書けない。
  module Stats
    Streak = Data.define(:current, :longest, :last_completed_date)
    DailyStat = Data.define(:date, :completed_count, :total_count)
    ProgressPoint = Data.define(:date, :max_weight, :total_reps, :total_volume)
    Overall = Data.define(:total_workouts, :total_duration_sec, :total_sets, :this_week_count)

    module_function

    # その日「やった」と数える基準。
    #
    # 全セット完了(completed)だけを対象にすると、4種目のうち3種目やった日が
    # ノーカウントになりストリークが切れる。習慣化アプリとしてそれは逆効果なので、
    # 中断(skipped)以外はすべて実施した日として扱う。
    def did_workout?(log)
      log.status != "skipped"
    end

    # 連続日数。
    #
    # 「今日まだやっていない」だけで途切れた表示になるのは体験が悪いので、
    # 最終実施日が今日か昨日ならストリークは生きているものとして数える。
    # この猶予が結果的に ±1日のタイムゾーンのズレも吸収している（意図的に維持する）。
    def calculate_streak(logs:, today:)
      dates = logs.select { did_workout?(_1) }.map { DateUtil.parse_date(_1.log_date) }.uniq.sort
      return Streak.new(current: 0, longest: 0, last_completed_date: nil) if dates.empty?

      longest = 1
      run = 1
      dates.each_cons(2) do |prev, curr|
        run = (curr - prev).to_i == 1 ? run + 1 : 1
        longest = [ longest, run ].max
      end

      last = dates.last
      current = 0
      if (DateUtil.parse_date(today) - last).to_i <= 1
        current = 1
        dates.each_cons(2).to_a.reverse_each do |prev, curr|
          break unless (curr - prev).to_i == 1

          current += 1
        end
      end

      Streak.new(current: current, longest: longest, last_completed_date: last)
    end

    # 直近n日分の実施状況。記録の無い日も0で埋めて古い順に返す
    def calculate_daily_stats(logs:, days:, today:)
      by_date = logs.group_by { DateUtil.format_date(DateUtil.parse_date(_1.log_date)) }
      base = DateUtil.parse_date(today)

      (days - 1).downto(0).map do |offset|
        date = DateUtil.format_date(base - offset)
        day_logs = by_date[date] || []
        DailyStat.new(
          date: date,
          completed_count: day_logs.count { did_workout?(_1) },
          total_count: day_logs.size
        )
      end
    end

    # カレンダーで塗る日
    def completed_dates(logs)
      logs.select { did_workout?(_1) }
          .map { DateUtil.format_date(DateUtil.parse_date(_1.log_date)) }
          .uniq
          .sort
    end

    # 種目ごとの推移。日付の古い順。自重(weight nil)は0として扱う
    def calculate_exercise_progress(exercise_id:, routine_logs:, exercise_logs:)
      date_by_log_id = routine_logs.to_h { [ _1.id, DateUtil.format_date(DateUtil.parse_date(_1.log_date)) ] }

      exercise_logs
        .select { _1.exercise_id == exercise_id && date_by_log_id.key?(_1.routine_log_id) }
        .group_by { date_by_log_id[_1.routine_log_id] }
        .map do |date, sets|
          ProgressPoint.new(
            date: date,
            max_weight: sets.map { (_1.actual_weight || 0).to_f }.max,
            total_reps: sets.sum { (_1.actual_reps || 0).to_i },
            total_volume: sets.sum { (_1.actual_weight || 0).to_f * (_1.actual_reps || 0).to_i }
          )
        end
        .sort_by(&:date)
    end

    # そのワークアウトの総挙上量(kg×回)。自重種目は0になる
    def calculate_volume(exercise_logs)
      exercise_logs.sum { (_1.actual_weight || 0).to_f * (_1.actual_reps || 0).to_i }
    end

    def calculate_overall_stats(routine_logs:, exercise_logs:, today:)
      done = routine_logs.select { did_workout?(_1) }
      week_ago = DateUtil.format_date(DateUtil.parse_date(today) - 6)

      Overall.new(
        total_workouts: done.size,
        total_duration_sec: done.sum { (_1.duration_sec || 0).to_i },
        total_sets: exercise_logs.size,
        this_week_count: done.count { DateUtil.format_date(DateUtil.parse_date(_1.log_date)) >= week_ago }
      )
    end

    # ワークアウト画面の「前回: …」に出す文字列。
    # packages/contract/domain_cases.json の formatPreviousSets が正。
    #
    # 表示文言はクライアントごとに書かない。
    # docs/FEATURES.md が「文言まで一致」を求めており、
    # 4実装に散らすと必ずどれかが古くなる
    def format_previous_sets(sets)
      sets.map { |set|
        duration = value_of(set, :duration_sec)
        next "#{duration}秒" if duration

        weight = value_of(set, :weight)
        reps = value_of(set, :reps)
        label = weight ? DateUtil.format_weight_number(weight) : "自重"
        "#{label}×#{reps || '-'}"
      }.join(" / ")
    end

    def value_of(set, key)
      set.respond_to?(key) ? set.public_send(key) : set[key]
    end
  end
end
