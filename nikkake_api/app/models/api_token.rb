# frozen_string_literal: true

# API トークン。
#
# 端末IDからは導出しない。端末IDは秘密ではなく（他アプリから読める）、
# リセットされると本人が締め出され、そもそも Web には存在しない。
# 256bit のランダム値を発行し、DB には SHA-256 ダイジェストだけを保存する。
class ApiToken < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil) }

  # 生トークンは発行時にしか存在しない。呼び出し側が受け取って一度だけ返す
  def self.issue!(user, device_label: nil)
    raw = SecureRandom.urlsafe_base64(32)
    token = create!(user: user, device_label: device_label, token_digest: digest(raw))
    [ token, raw ]
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    token = active.find_by(token_digest: digest(raw))
    token&.update_column(:last_used_at, Time.current)
    token
  end

  def self.digest(raw)
    OpenSSL::Digest::SHA256.hexdigest(raw)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
