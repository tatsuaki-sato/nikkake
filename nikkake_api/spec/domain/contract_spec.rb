# frozen_string_literal: true

require "json"
require_relative "../../lib/domain/date_util"
require_relative "../../lib/domain/schedule"
require_relative "../../lib/domain/stats"

# packages/contract/domain_cases.json を唯一の期待値として検証する。
#
# TypeScript (nikkake_react_native/src/lib/__tests__/contract.test.ts) が
# 同じ JSON を読んでおり、Dart / Kotlin も後続フェーズで追加する。
# 5言語が同じ答えを返すことを CI で機械的に保証するのが目的。
#
# ここが落ちたら、まず Ruby 側の移植を疑うこと。
# 期待値を書き換えて通すのは、仕様変更だと確信できるときだけ。
RSpec.describe "ドメイン契約" do
  # 日本語のケース名を含むので UTF-8 を明示する（環境によっては US-ASCII と判断される）
  CASES = JSON.parse(
    File.read(
      File.expand_path("../../../packages/contract/domain_cases.json", __dir__),
      encoding: "UTF-8"
    )
  ).freeze

  # ActiveRecord に依存せず、ドメイン関数が必要とするメソッドだけを持つ軽量な値
  Log = Struct.new(:id, :log_date, :status, :duration_sec, keyword_init: true)
  SetLog = Struct.new(:routine_log_id, :exercise_id, :set_number, :actual_reps, :actual_weight, keyword_init: true)
  RoutineStub = Struct.new(:is_active, :frequency_type, :frequency_value, :frequency_days, keyword_init: true)

  def build_log(raw)
    Log.new(
      id: raw["id"] || "log-#{raw['log_date']}-#{raw['status']}",
      log_date: raw["log_date"],
      status: raw["status"] || "completed",
      duration_sec: raw["duration_sec"]
    )
  end

  def build_set_log(raw)
    SetLog.new(
      routine_log_id: raw["routine_log_id"],
      exercise_id: raw["exercise_id"],
      set_number: raw["set_number"],
      actual_reps: raw["actual_reps"],
      actual_weight: raw["actual_weight"]
    )
  end

  def build_routine(raw)
    RoutineStub.new(
      is_active: raw.fetch("is_active", true),
      frequency_type: raw["frequency_type"],
      frequency_value: raw["frequency_value"],
      frequency_days: raw["frequency_days"]
    )
  end

  describe "streak" do
    CASES["streak"]["cases"].each do |c|
      it c["name"] do
        result = Domain::Stats.calculate_streak(
          logs: c["logs"].map { build_log(_1) },
          today: Date.parse(c["today"])
        )

        expect(result.current).to eq(c["expect"]["current"])
        expect(result.longest).to eq(c["expect"]["longest"])

        expected_last = c["expect"]["lastCompletedDate"]
        actual_last = result.last_completed_date && Domain::DateUtil.format_date(result.last_completed_date)
        expect(actual_last).to eq(expected_last)
      end
    end
  end

  describe "dueToday" do
    CASES["dueToday"]["cases"].each do |c|
      it c["name"] do
        result = Domain::Schedule.due_today?(
          routine: build_routine(c["routine"]),
          last_log: c["lastLog"] && build_log(c["lastLog"]),
          today: Date.parse(c["today"])
        )

        expect(result).to eq(c["expect"])
      end
    end
  end

  describe "dailyStats" do
    CASES["dailyStats"]["cases"].each do |c|
      it c["name"] do
        result = Domain::Stats.calculate_daily_stats(
          logs: c["logs"].map { build_log(_1) },
          days: c["days"],
          today: Date.parse(c["today"])
        )

        expect(result.map { { "date" => _1.date, "completedCount" => _1.completed_count, "totalCount" => _1.total_count } })
          .to eq(c["expect"])
      end
    end
  end

  describe "exerciseProgress" do
    CASES["exerciseProgress"]["cases"].each do |c|
      it c["name"] do
        result = Domain::Stats.calculate_exercise_progress(
          exercise_id: c["exerciseId"],
          routine_logs: c["routineLogs"].map { build_log(_1) },
          exercise_logs: c["exerciseLogs"].map { build_set_log(_1) }
        )

        expect(result.map { { "date" => _1.date, "maxWeight" => _1.max_weight, "totalReps" => _1.total_reps, "totalVolume" => _1.total_volume } })
          .to eq(c["expect"].map { _1.merge("maxWeight" => _1["maxWeight"].to_f, "totalVolume" => _1["totalVolume"].to_f) })
      end
    end
  end

  describe "overallStats" do
    CASES["overallStats"]["cases"].each do |c|
      it c["name"] do
        result = Domain::Stats.calculate_overall_stats(
          routine_logs: c["routineLogs"].map { build_log(_1) },
          exercise_logs: c["exerciseLogs"].map { build_set_log(_1) },
          today: Date.parse(c["today"])
        )

        expect({
          "totalWorkouts" => result.total_workouts,
          "totalDurationSec" => result.total_duration_sec,
          "totalSets" => result.total_sets,
          "thisWeekCount" => result.this_week_count
        }).to eq(c["expect"])
      end
    end
  end

  describe "formatDuration" do
    CASES["formatDuration"]["cases"].each do |c|
      it c["name"] do
        expect(Domain::DateUtil.format_duration(c["seconds"])).to eq(c["expect"])
      end
    end
  end

  describe "formatWeight" do
    CASES["formatWeight"]["cases"].each do |c|
      it c["name"] do
        expect(Domain::DateUtil.format_weight(c["weight"])).to eq(c["expect"])
      end
    end
  end

  describe "formatFrequency" do
    CASES["formatFrequency"]["cases"].each do |c|
      it c["name"] do
        expect(Domain::Schedule.frequency_label(build_routine(c["routine"]))).to eq(c["expect"])
      end
    end
  end

  describe "greetingForHour" do
    CASES["greetingForHour"]["cases"].each do |c|
      it c["name"] do
        expect(Domain::DateUtil.greeting_for_hour(c["hour"])).to eq(c["expect"])
      end
    end
  end

  describe "formatPreviousSets" do
    CASES["formatPreviousSets"]["cases"].each do |c|
      it c["name"] do
        sets = c["sets"].map { _1.transform_keys(&:to_sym) }
        expect(Domain::Stats.format_previous_sets(sets)).to eq(c["expect"])
      end
    end
  end
end
