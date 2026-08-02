# frozen_string_literal: true

module Types
  class TodayRoutineType < BaseObject
    graphql_name "TodayRoutine"
    field :routine, RoutineType, null: false
    field :is_due_today, Boolean, null: false
    field :is_completed, Boolean, null: false,
          description: "全セット完了でなくても、記録を残していれば true（skipped のみは false）"
    field :last_log, RoutineLogType
    field :frequency_label, String, null: false,
          description: "「毎日」「3日ごと」「月・水」。文言をサーバに寄せて4実装のズレを消す"
  end
end
