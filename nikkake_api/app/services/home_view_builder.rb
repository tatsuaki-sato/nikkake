# frozen_string_literal: true

# ホーム画面ぶんを一括で組み立てる。
#
# 「今日やる分 / 今日は予定なし / 完了」の区分もサーバが決める。
# 汎用的な routines { logs { ... } } を返して各クライアントに集計させると、
# 結局4実装に同じロジックが戻ってしまう。
#
# today は必ず呼び出し側（＝クライアントが送ってきた値）から受け取る。
# ここで求めるとタイムゾーンで1日ずれる。
class HomeViewBuilder
  Item = Data.define(:routine, :is_due_today, :is_completed, :last_log, :frequency_label)
  View = Data.define(:today, :streak, :due, :not_scheduled, :completed)

  def initialize(user:, today:)
    @user = user
    @today = today
  end

  def call
    # クエリを2本に固定する。GraphQL の解決順に依存させない
    routines = @user.routines.kept.where(is_active: true).ordered
                    .includes(routine_exercises: :exercise).to_a
    logs = @user.routine_logs.kept.to_a

    logs_by_routine = logs.group_by(&:routine_id)
    today_string = Domain::DateUtil.format_date(@today)

    items = routines.map do |routine|
      routine_logs = (logs_by_routine[routine.id] || []).sort_by(&:log_date).reverse
      today_log = routine_logs.find { Domain::DateUtil.format_date(_1.log_date) == today_string }
      last_log = routine_logs.find { Domain::Stats.did_workout?(_1) }

      Item.new(
        routine: routine,
        is_due_today: Domain::Schedule.due_today?(routine: routine, last_log: last_log, today: @today),
        # 全セット完了でなくても、記録を残した時点で今日の分は済んだものとして扱う。
        # ストリークの判定と基準を揃えている。
        is_completed: today_log.present? && Domain::Stats.did_workout?(today_log),
        last_log: last_log,
        frequency_label: Domain::Schedule.frequency_label(routine)
      )
    end

    View.new(
      today: @today,
      streak: Domain::Stats.calculate_streak(logs: logs, today: @today),
      due: items.select { _1.is_due_today && !_1.is_completed },
      not_scheduled: items.reject { _1.is_due_today || _1.is_completed },
      completed: items.select(&:is_completed)
    )
  end
end
