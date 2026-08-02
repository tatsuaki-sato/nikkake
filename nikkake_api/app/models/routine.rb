# frozen_string_literal: true

class Routine < ApplicationRecord
  include UserOwned

  FREQUENCY_TYPES = %w[daily every_n_days weekly].freeze

  has_many :routine_exercises, dependent: :destroy
  has_many :routine_logs, dependent: :destroy

  validates :name, presence: true
  validates :frequency_type, inclusion: { in: FREQUENCY_TYPES }
  validates :frequency_value, numericality: { greater_than_or_equal_to: 1 }

  scope :ordered, -> { order(:sort_order, :created_at) }
end
