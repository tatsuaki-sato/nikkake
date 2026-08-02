# frozen_string_literal: true

# 匿名アカウントの発行。
#
# クライアントは識別情報を一切送らない。サーバが新規ユーザーを作り、
# 端末IDから導出しない 256bit のランダムトークンを返す。
# ユーザーから見ればログイン画面は一切出ない。
class AccountCreator
  Result = Data.define(:user, :raw_token)

  def self.call(time_zone:, device_label: nil)
    user = User.create!(time_zone: time_zone.presence || "Asia/Tokyo", last_seen_at: Time.current)
    _token, raw = ApiToken.issue!(user, device_label: device_label)

    Result.new(user: user, raw_token: raw)
  end
end
