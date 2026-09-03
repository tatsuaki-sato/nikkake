# frozen_string_literal: true

module Types
  class DayExerciseSummaryType < BaseObject
    graphql_name "DayExerciseSummary"
    field :exercise_name, String, null: false
    field :sets_label, String,
          description: "「50.0×10 / 50.0×8」形式の整形済み文字列。セット記録が無ければ null。文言はサーバが返す"
  end
end
