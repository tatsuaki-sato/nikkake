# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ワークアウトの記録と集計" do
  before { PresetSyncer.call }

  let(:user) { AccountCreator.call(time_zone: "Asia/Tokyo").user }
  let(:routine) { StarterRoutineBuilder.call(user: user) }
  let(:today) { Date.new(2026, 8, 5) }

  # クライアントが送ってくる形をそのまま組み立てる
  def record(log_date: today, sets: [], total_sets: 11, id: SecureRandom.uuid, duration_sec: 600)
    WorkoutRecorder.new(
      user: user,
      input: {
        id: id,
        routine_id: routine.id,
        log_date: Domain::DateUtil.format_date(log_date),
        time_zone: "Asia/Tokyo",
        started_at: Time.current,
        duration_sec: duration_sec,
        total_sets: total_sets,
        sets: sets
      }
    ).call
  end

  def set_row(exercise_id:, number: 1, reps: 10, weight: 50.0)
    {
      id: SecureRandom.uuid,
      routine_exercise_id: nil,
      exercise_id: exercise_id,
      set_number: number,
      actual_reps: reps,
      actual_weight: weight,
      actual_duration_sec: nil
    }
  end

  let(:push_up_id) { "00000000-0000-4000-8000-000000000003" }

  describe WorkoutRecorder do
    it "完了セット数からサーバが status を判定する（クライアントは送らない）" do
      expect(record(sets: [], total_sets: 3).routine_log.status).to eq("skipped")
      expect(record(sets: [ set_row(exercise_id: push_up_id) ], total_sets: 3).routine_log.status).to eq("partial")

      full = 3.times.map { set_row(exercise_id: push_up_id, number: _1 + 1) }
      expect(record(sets: full, total_sets: 3).routine_log.status).to eq("completed")
    end

    it "同じ id で再送しても二重登録されない（オフラインキューの冪等性）" do
      id = SecureRandom.uuid
      sets = [ set_row(exercise_id: push_up_id) ]

      record(id: id, sets: sets)
      record(id: id, sets: sets)

      expect(user.routine_logs.kept.count).to eq(1)
      expect(user.exercise_logs.kept.count).to eq(1)
    end

    it "記録時のタイムゾーンとオフセットを保存する" do
      log = record(sets: []).routine_log

      expect(log.client_time_zone).to eq("Asia/Tokyo")
      expect(log.client_utc_offset_minutes).to eq(540)
    end

    it "log_date はクライアントが送った値をそのまま使う" do
      log = record(log_date: Date.new(2026, 1, 1)).routine_log
      expect(log.log_date).to eq(Date.new(2026, 1, 1))
    end

    it "サマリーに総重量が入る。自重種目は0として扱う" do
      result = record(sets: [
        set_row(exercise_id: push_up_id, number: 1, reps: 10, weight: 50.0),
        set_row(exercise_id: push_up_id, number: 2, reps: 10, weight: nil)
      ])

      expect(result.summary.total_volume).to eq(500.0)
      expect(result.summary.completed_sets).to eq(2)
    end

    it "削除済みルーティンへの記録も受け付ける" do
      # オフラインキューが削除済みルーティンへの記録を持ちうるので、
      # ここで弾くと永久に送信できないレコードが生まれる
      routine.soft_delete!

      expect { record(sets: [ set_row(exercise_id: push_up_id) ]) }.not_to raise_error
    end

    it "他人のルーティンには記録できない" do
      other = AccountCreator.call(time_zone: "Asia/Tokyo").user
      other_routine = StarterRoutineBuilder.call(user: other)

      recorder = WorkoutRecorder.new(user: user, input: {
        id: SecureRandom.uuid, routine_id: other_routine.id,
        log_date: "2026-08-05", time_zone: "Asia/Tokyo",
        started_at: Time.current, duration_sec: 0, total_sets: 1, sets: []
      })

      expect { recorder.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe HomeViewBuilder do
    it "今日やる分・予定なし・完了に区分する" do
      routine
      view = described_class.new(user: user, today: today).call

      expect(view.due.size).to eq(1)
      expect(view.completed).to be_empty
      expect(view.due.first.frequency_label).to eq("毎日")
    end

    it "途中までの記録でも今日の分は完了扱いになる" do
      routine
      record(sets: [ set_row(exercise_id: push_up_id) ], total_sets: 11)

      view = described_class.new(user: user, today: today).call

      expect(view.completed.size).to eq(1)
      expect(view.due).to be_empty
    end

    it "中断だけなら完了扱いにならない" do
      routine
      record(sets: [], total_sets: 11)

      view = described_class.new(user: user, today: today).call

      expect(view.due.size).to eq(1)
      expect(view.completed).to be_empty
    end

    it "停止中のルーティンは出てこない" do
      routine.update!(is_active: false)
      view = described_class.new(user: user, today: today).call

      expect(view.due + view.not_scheduled + view.completed).to be_empty
    end
  end

  describe WorkoutSessionBuilder do
    it "前回の記録を種目ごとに解決して返す" do
      routine
      record(sets: [
        set_row(exercise_id: push_up_id, number: 1, reps: 12, weight: 55.0),
        set_row(exercise_id: push_up_id, number: 2, reps: 10, weight: 60.0)
      ])

      session = described_class.new(user: user, routine: routine).call
      entry = session.exercises.find { _1.exercise.id == push_up_id }

      expect(entry.previous_sets.size).to eq(2)
      expect(entry.previous_sets.first.reps).to eq(12)
      expect(entry.previous_label).to eq("55×12 / 60×10")
    end

    it "記録が無ければ前回欄は空になる" do
      session = described_class.new(user: user, routine: routine).call

      expect(session.exercises).to all(have_attributes(previous_sets: [], previous_label: nil))
    end

    it "時間計測の種目は秒として表示される" do
      routine
      plank_id = "00000000-0000-4000-8000-000000000018"
      record(sets: [ {
        id: SecureRandom.uuid, routine_exercise_id: nil, exercise_id: plank_id,
        set_number: 1, actual_reps: nil, actual_weight: nil, actual_duration_sec: 30
      } ])

      session = described_class.new(user: user, routine: routine).call
      entry = session.exercises.find { _1.exercise.id == plank_id }

      expect(entry.previous_label).to eq("30秒")
    end
  end

  describe "ルーティンを編集しても履歴が途切れない" do
    it "routine_exercises を作り直しても exercise_id 経由で辿れる" do
      routine
      record(sets: [ set_row(exercise_id: push_up_id) ])

      RoutineWriter.new(user: user).update(routine, {
        name: "編集後", icon: "💪", color: "#6C5CE7",
        frequency_type: "daily", frequency_value: 1, frequency_days: [],
        lock_version: routine.lock_version,
        exercises: [ { id: SecureRandom.uuid, exercise_id: push_up_id, target_sets: 3, target_reps: 10 } ]
      })

      progress = Domain::Stats.calculate_exercise_progress(
        exercise_id: push_up_id,
        routine_logs: user.routine_logs.kept.to_a,
        exercise_logs: user.exercise_logs.kept.to_a
      )

      expect(progress.size).to eq(1)
      expect(user.exercise_logs.kept.count).to eq(1)
    end
  end

  describe RoutineWriter do
    it "他端末で更新されていたら弾く（楽観ロック）" do
      writer = described_class.new(user: user)
      stale_version = routine.lock_version

      writer.update(routine, base_input(stale_version))
      routine.reload

      expect { writer.update(routine, base_input(stale_version)) }
        .to raise_error(RoutineWriter::Conflict)
    end

    def base_input(lock_version)
      {
        name: "更新", icon: "💪", color: "#6C5CE7",
        frequency_type: "daily", frequency_value: 1, frequency_days: [],
        lock_version: lock_version,
        exercises: [ { id: SecureRandom.uuid, exercise_id: push_up_id, target_sets: 3, target_reps: 10 } ]
      }
    end
  end
end
