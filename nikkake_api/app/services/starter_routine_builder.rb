# frozen_string_literal: true

# 初回のルーティン投入。
#
# 「アプリを開いた瞬間に、いつものルーティンが始められる」状態にするためのもの。
# 器具なしで自宅でできる種目だけで構成する。
#
# 遅延登録（クライアントが先にローカルでシードしてから importSnapshot する）経路が
# 主だが、Web のように端末シードを持たない場合はここで作る。
class StarterRoutineBuilder
  NAME = "いつものルーティン"
  DESCRIPTION = "器具なしで今すぐ始められる基本メニューです。自由に編集してください。"

  # exercise_id は packages/contract/preset_exercises.json の固定UUID
  EXERCISES = [
    { exercise_id: "00000000-0000-4000-8000-000000000003", sets: 3, reps: 10,  duration: nil, rest: 60 },
    { exercise_id: "00000000-0000-4000-8000-000000000009", sets: 3, reps: 15,  duration: nil, rest: 60 },
    { exercise_id: "00000000-0000-4000-8000-000000000017", sets: 3, reps: 20,  duration: nil, rest: 45 },
    { exercise_id: "00000000-0000-4000-8000-000000000018", sets: 2, reps: nil, duration: 30,  rest: 45 }
  ].freeze

  def self.call(user:)
    return user.routines.kept.first if user.routines.kept.exists?

    ActiveRecord::Base.transaction do
      routine = user.routines.create!(
        id: SecureRandom.uuid,
        name: NAME,
        description: DESCRIPTION,
        color: "#6C5CE7",
        icon: "💪",
        frequency_type: "daily",
        frequency_value: 1,
        frequency_days: [],
        sort_order: 0
      )

      EXERCISES.each_with_index do |e, index|
        routine.routine_exercises.create!(
          id: SecureRandom.uuid,
          user: user,
          exercise_id: e[:exercise_id],
          sort_order: index,
          target_sets: e[:sets],
          target_reps: e[:reps],
          target_duration_sec: e[:duration],
          rest_sec: e[:rest]
        )
      end

      routine
    end
  end
end
