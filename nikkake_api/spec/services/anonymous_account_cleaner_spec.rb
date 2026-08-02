# frozen_string_literal: true

require "rails_helper"

# 使われなくなった匿名アカウントの削除。
#
# 消すことより「消さないこと」の検証が大事。
# 匿名アカウントは取り戻す手段が端末のトークンしか無いので、
# 誤って消すとユーザーは記録を失い、こちらから復旧する手段もない。
RSpec.describe AnonymousAccountCleaner do
  let(:now) { Time.zone.parse("2026-08-03 12:00:00") }

  def anonymous(last_seen:)
    User.create!(time_zone: "Asia/Tokyo", last_seen_at: last_seen)
  end

  describe "消すもの" do
    it "記録が無く、90日アクセスの無い匿名アカウント" do
      target = anonymous(last_seen: now - 91.days)

      expect { described_class.call(now: now) }.to change(User, :count).by(-1)
      expect(User.exists?(target.id)).to be(false)
    end

    it "トークンも一緒に消える" do
      target = anonymous(last_seen: now - 91.days)
      ApiToken.issue!(target)

      expect { described_class.call(now: now) }.to change(ApiToken, :count).by(-1)
    end
  end

  describe "消さないもの" do
    it "記録が1件でもあれば消さない（長く使っていなくても、戻ってきたときに残っている方が正しい）" do
      user = anonymous(last_seen: now - 400.days)
      routine = user.routines.create!(name: "テスト", color: "#6C5CE7", icon: "💪",
                                      frequency_type: "daily", frequency_value: 1)
      user.routine_logs.create!(routine: routine, log_date: Date.new(2026, 1, 1), status: "completed")

      expect { described_class.call(now: now) }.not_to change(User, :count)
    end

    it "メール登録済みは対象外（何年使っていなくても消さない）" do
      user = anonymous(last_seen: now - 400.days)
      user.update!(email: "someone@example.com", password: "password123")

      expect { described_class.call(now: now) }.not_to change(User, :count)
    end

    it "まだ90日経っていないものは消さない" do
      anonymous(last_seen: now - 89.days)

      expect { described_class.call(now: now) }.not_to change(User, :count)
    end

    it "境界（ちょうど90日）は消さない" do
      anonymous(last_seen: now - 90.days)

      expect { described_class.call(now: now) }.not_to change(User, :count)
    end
  end

  describe "dry_run" do
    it "件数だけ数えて消さない" do
      anonymous(last_seen: now - 91.days)

      result = nil
      expect { result = described_class.call(now: now, dry_run: true) }.not_to change(User, :count)
      expect(result.scanned).to eq(1)
      expect(result.deleted).to eq(0)
    end
  end

  it "期間は変えられる" do
    anonymous(last_seen: now - 31.days)

    expect { described_class.call(idle_days: 30, now: now) }.to change(User, :count).by(-1)
  end
end
