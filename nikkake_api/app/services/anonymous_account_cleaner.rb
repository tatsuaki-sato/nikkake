# frozen_string_literal: true

# 使われなくなった匿名アカウントを消す。
#
# クラス名に GC を使わないのは Zeitwerk が略語を解決できないため
# （anonymous_account_gc.rb は AnonymousAccountGc を期待する）。
# 略語1つのために全体の変換規則を足す方が害が大きい。
#
# 「ログイン不要で使える」の裏返しとして、アプリを開いただけで
# ユーザー行が1つ増えます。放置するとDBが埋まるので定期的に掃除します。
#
# **消す条件を絞っているのは、消してはいけないものを消さないためです。**
# 匿名アカウントは取り戻す手段が端末のトークンしか無いので、
# 誤って消すとユーザーは記録を失い、こちらから復旧する手段もありません。
class AnonymousAccountCleaner
  # 記録が1件も無く、これだけの期間アクセスが無かったものだけを消す。
  #
  # 記録があるアカウントは消しません。
  # 端末を長期間使っていなくても、戻ってきたときに記録が残っている方が正しい。
  DEFAULT_IDLE_DAYS = 90

  Result = Data.define(:deleted, :scanned)

  def self.call(idle_days: DEFAULT_IDLE_DAYS, dry_run: false, now: Time.current)
    threshold = now - idle_days.days

    scope = User
      .where(email: nil)                       # 匿名だけ。メール登録済みは対象外
      .where("last_seen_at < ?", threshold)
      .where.missing(:routine_logs)            # 記録があるものは消さない

    scanned = scope.count
    return Result.new(deleted: 0, scanned: scanned) if dry_run

    # 関連ごと消す。routines / routine_exercises / api_tokens は
    # dependent: :destroy で追随する
    deleted = scope.destroy_all.size

    Result.new(deleted: deleted, scanned: scanned)
  end
end
