# frozen_string_literal: true

# ルーティンの作成・更新。
#
# 種目構成は丸ごと差し替える（既存を論理削除して再挿入）。
# 差分更新にすると並び順の入れ替えが複雑になるため。
# 過去のログは exercise_id で辿れるので、作り直しても履歴グラフは途切れない。
class RoutineWriter
  DEFAULT_REST_SEC = 60

  class Conflict < StandardError; end

  def initialize(user:)
    @user = user
  end

  def create(input)
    ActiveRecord::Base.transaction do
      routine = @user.routines.create!(
        id: input[:id],
        name: input[:name],
        description: input[:description],
        color: input[:color],
        icon: input[:icon],
        frequency_type: input[:frequency_type],
        frequency_value: input[:frequency_value] || 1,
        frequency_days: input[:frequency_days] || [],
        sort_order: @user.routines.kept.count
      )
      replace_exercises(routine, input[:exercises])
      routine
    end
  end

  def update(routine, input)
    ActiveRecord::Base.transaction do
      # 他端末で更新されていたら弾く。移行前の last-write-wins の置き換え
      raise Conflict if input[:lock_version] && routine.lock_version != input[:lock_version]

      routine.update!(
        name: input[:name],
        description: input[:description],
        color: input[:color],
        icon: input[:icon],
        frequency_type: input[:frequency_type],
        frequency_value: input[:frequency_value] || 1,
        frequency_days: input[:frequency_days] || [],
        is_active: input.fetch(:is_active, true)
      )
      replace_exercises(routine, input[:exercises])
      routine
    end
  rescue ActiveRecord::StaleObjectError
    raise Conflict
  end

  def delete(routine)
    ActiveRecord::Base.transaction do
      routine.routine_exercises.kept.find_each(&:soft_delete!)
      routine.soft_delete!
    end
    routine
  end

  private

  def replace_exercises(routine, exercises)
    routine.routine_exercises.kept.find_each(&:soft_delete!)
    return if exercises.blank?

    now = Time.current
    rows = exercises.each_with_index.map do |e, index|
      {
        id: e[:id] || SecureRandom.uuid,
        user_id: @user.id,
        routine_id: routine.id,
        exercise_id: e[:exercise_id],
        sort_order: index,
        target_sets: e[:target_sets],
        target_reps: e[:target_reps],
        target_weight: e[:target_weight],
        target_duration_sec: e[:target_duration_sec],
        rest_sec: e[:rest_sec] || DEFAULT_REST_SEC,
        created_at: now,
        updated_at: now
      }
    end
    RoutineExercise.insert_all(rows, unique_by: :id)
  end
end
