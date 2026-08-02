# frozen_string_literal: true

# 種目マスタ。
# is_preset = true は全ユーザー共有で、固定UUIDを持つ（packages/contract/preset_exercises.json が正）。
# カスタム種目は created_by が所有者。
class Exercise < ApplicationRecord
  CATEGORIES = %w[strength cardio game custom].freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :routine_exercises, dependent: :restrict_with_exception
  has_many :exercise_logs, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :kept, -> { where(deleted_at: nil) }
  scope :presets, -> { where(is_preset: true) }
  scope :changed_since, ->(cursor) { cursor ? where(arel_table[:updated_at].gt(cursor)) : all }

  # プリセットと自分のカスタムだけ
  scope :visible_to, ->(user) { where(is_preset: true).or(where(created_by_id: user.id)) }
end
