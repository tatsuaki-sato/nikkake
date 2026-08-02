# frozen_string_literal: true

# セット1本分。完了にしたセットだけが保存される。
#
# exercise_id を持たせているのが要点。routine_exercises はルーティン編集の
# たびに作り直されるので、そこ経由で履歴を辿ると編集した時点でグラフが途切れる。
class ExerciseLog < ApplicationRecord
  include UserOwned

  belongs_to :routine_log
  belongs_to :exercise
  belongs_to :routine_exercise, optional: true

  validates :set_number, numericality: { greater_than_or_equal_to: 1 }
end
