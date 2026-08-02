# frozen_string_literal: true

# 匿名アカウントの発行。
#
# クライアントは識別情報を一切送らない。サーバが新規ユーザーを作り、
# 端末IDから導出しない 256bit のランダムトークンを返す。
# ユーザーから見ればログイン画面は一切出ない。
class AccountCreator
  Result = Data.define(:user, :raw_token)

  def self.call(time_zone:, device_label: nil)
    user = User.create!(time_zone: normalize_time_zone(time_zone), last_seen_at: Time.current)
    _token, raw = ApiToken.issue!(user, device_label: device_label)

    Result.new(user: user, raw_token: raw)
  end

  # 未知のタイムゾーンを素通しさせない。
  #
  # クライアントによっては IANA 名ではなく略称（"JST" など）を送ってくる。
  # そのまま保存すると ActiveSupport::TimeZone が解決できず、
  # バッチ処理が黙って動かなくなる。
  #
  # なお、この値は判定には使わない（日付は常にリクエストの値が優先）。
  # 保存しているのは事故が起きたときに検証・救済するためで、
  # だからこそ解決できる形で入っている必要がある。
  def self.normalize_time_zone(value)
    candidate = value.to_s.strip
    return "Asia/Tokyo" if candidate.empty?
    return candidate if ActiveSupport::TimeZone[candidate]

    # 略称は Ruby 側で解決できないので、既定へ寄せる
    "Asia/Tokyo"
  end
  private_class_method :normalize_time_zone
end
