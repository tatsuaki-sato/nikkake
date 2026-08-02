# frozen_string_literal: true

namespace :accounts do
  desc "使われていない匿名アカウントを消す（IDLE_DAYS=90, DRY_RUN=1 で件数だけ）"
  task cleanup: :environment do
    idle_days = Integer(ENV.fetch("IDLE_DAYS", AnonymousAccountCleaner::DEFAULT_IDLE_DAYS))
    dry_run = ENV["DRY_RUN"].present?

    result = AnonymousAccountCleaner.call(idle_days: idle_days, dry_run: dry_run)

    label = dry_run ? "対象" : "削除"
    puts "#{label}: #{dry_run ? result.scanned : result.deleted} 件" \
         "（#{idle_days}日以上アクセスが無く、記録が1件も無い匿名アカウント）"
  end
end
