# frozen_string_literal: true

# ルーティン内の種目。
# ルーティン編集のたびに丸ごと作り直される（既存を論理削除して再挿入）。
# 差分更新にすると並び順の入れ替えが複雑になるため。
class RoutineExercise < ApplicationRecord
  include UserOwned

  belongs_to :routine
  belongs_to :exercise

  validates :target_sets, numericality: { greater_than_or_equal_to: 1 }

  scope :ordered, -> { order(:sort_order) }
end
