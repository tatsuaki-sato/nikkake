# frozen_string_literal: true

require "rails_helper"

RSpec.describe "匿名アカウントと初期ルーティン" do
  # プリセット種目は全ユーザー共有のマスタなので、常に存在する前提にする
  before { PresetSyncer.call }

  describe AccountCreator do
    it "識別情報を受け取らずに匿名ユーザーとトークンを発行する" do
      result = described_class.call(time_zone: "Asia/Tokyo")

      expect(result.user).to be_anonymous
      expect(result.user.email).to be_nil
      expect(result.user.time_zone).to eq("Asia/Tokyo")
      expect(result.raw_token).to be_present
    end

    it "トークンは端末IDから導出せず、DBにはダイジェストだけを保存する" do
      result = described_class.call(time_zone: "Asia/Tokyo")
      token = result.user.api_tokens.sole

      # 生トークンはどのカラムにも入っていない
      expect(token.token_digest).not_to eq(result.raw_token)
      expect(token.attributes.values.map(&:to_s)).not_to include(result.raw_token)
      # 256bit を urlsafe_base64 したもの
      expect(result.raw_token.length).to eq(43)
    end

    it "同じ条件で2回発行してもトークンは重複しない" do
      a = described_class.call(time_zone: "Asia/Tokyo")
      b = described_class.call(time_zone: "Asia/Tokyo")

      expect(a.raw_token).not_to eq(b.raw_token)
      expect(a.user.id).not_to eq(b.user.id)
    end
  end

  describe ApiToken do
    let!(:result) { AccountCreator.call(time_zone: "Asia/Tokyo") }

    it "正しいトークンで認証できる" do
      expect(described_class.authenticate(result.raw_token)&.user_id).to eq(result.user.id)
    end

    it "偽のトークンでは認証できない" do
      expect(described_class.authenticate("fake-token")).to be_nil
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
    end

    it "失効させたトークンでは認証できない" do
      result.user.api_tokens.sole.revoke!
      expect(described_class.authenticate(result.raw_token)).to be_nil
    end
  end

  describe "匿名からメール登録への昇格" do
    let(:user) { AccountCreator.call(time_zone: "Asia/Tokyo").user }

    it "user.id が変わらないのでデータ移行が発生しない" do
      StarterRoutineBuilder.call(user: user)
      original_id = user.id
      routine_ids = user.routines.pluck(:id)

      user.attach_email_password!(email: "a@example.com", password: "secret123")

      expect(user.id).to eq(original_id)
      expect(user.reload.routines.pluck(:id)).to match_array(routine_ids)
      expect(user).not_to be_anonymous
    end

    it "パスワードで認証できるようになる" do
      user.attach_email_password!(email: "b@example.com", password: "secret123")

      expect(User.authenticate_by(email: "b@example.com", password: "secret123")).to eq(user)
      expect(User.authenticate_by(email: "b@example.com", password: "wrong")).to be_nil
    end

    it "二重に昇格させようとすると弾く" do
      user.attach_email_password!(email: "c@example.com", password: "secret123")

      expect { user.attach_email_password!(email: "d@example.com", password: "secret123") }
        .to raise_error(User::AlreadyPromoted)
    end

    it "同じメールアドレスは2アカウントで使えない" do
      user.attach_email_password!(email: "dup@example.com", password: "secret123")
      other = AccountCreator.call(time_zone: "Asia/Tokyo").user

      expect { other.attach_email_password!(email: "dup@example.com", password: "secret123") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe StarterRoutineBuilder do
    let(:user) { AccountCreator.call(time_zone: "Asia/Tokyo").user }

    it "起動直後に始められるルーティンを1つ用意する" do
      routine = described_class.call(user: user)

      expect(routine.name).to eq("いつものルーティン")
      expect(routine.routine_exercises.count).to eq(4)
      expect(routine).to be_is_active
    end

    it "種目はすべて器具なしで、プリセットの固定UUIDを指している" do
      routine = described_class.call(user: user)
      ids = routine.routine_exercises.ordered.pluck(:exercise_id)

      expect(ids).to eq(described_class::EXERCISES.map { _1[:exercise_id] })
      expect(Exercise.where(id: ids).pluck(:name))
        .to match_array([ "腕立て伏せ", "スクワット", "腹筋（クランチ）", "プランク" ])
    end

    it "時間計測の種目には秒数、回数の種目には回数が入る" do
      routine = described_class.call(user: user)
      plank = routine.routine_exercises.ordered.last

      expect(plank.target_duration_sec).to eq(30)
      expect(plank.target_reps).to be_nil
    end

    it "既にルーティンがある場合は作り直さない" do
      first = described_class.call(user: user)
      second = described_class.call(user: user)

      expect(second.id).to eq(first.id)
      expect(user.routines.kept.count).to eq(1)
    end
  end

  describe "論理削除" do
    let(:user) { AccountCreator.call(time_zone: "Asia/Tokyo").user }

    it "削除しても行は残る。オフラインキューが削除済みルーティンへの記録を持ちうるため" do
      routine = StarterRoutineBuilder.call(user: user)
      routine.soft_delete!

      expect(user.routines.kept).to be_empty
      expect(user.routines.count).to eq(1)
      expect(routine.reload.deleted_at).to be_present
    end
  end
end
