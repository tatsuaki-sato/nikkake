# frozen_string_literal: true

# プリセット種目をDBへ反映する。
# 何度実行しても同じ結果になるので、デプロイのたびに db:seed から呼べる。
class PresetSyncer
  def self.call
    now = Time.current

    rows = Domain::PresetExercises.all.map do |p|
      {
        id: p["id"],
        name: p["name"],
        category: p["category"],
        description: p["description"],
        icon: p["icon"],
        is_preset: true,
        created_at: now,
        updated_at: now
      }
    end

    Exercise.upsert_all(rows, unique_by: :id, update_only: %i[name category description icon])
    rows.size
  end
end
