# frozen_string_literal: true

# ワークアウト1回分。
# log_date はクライアントが端末のタイムゾーンで決めて送る。
# サーバが UTC から導出すると、日本の朝8時が前日扱いになり1日ずれる。
class RoutineLog < ApplicationRecord
  include UserOwned

  STATUSES = %w[completed partial skipped].freeze

  belongs_to :routine
  has_many :exercise_logs, dependent: :destroy

  validates :log_date, presence: true
  validates :status, inclusion: { in: STATUSES }

  # 中断以外を「実施した」と数える。Domain::Stats.did_workout? と同じ基準
  scope :did_workout, -> { where.not(status: "skipped") }
end
