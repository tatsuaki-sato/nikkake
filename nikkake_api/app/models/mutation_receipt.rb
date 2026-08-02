# frozen_string_literal: true

# ミューテーションの応答レシート。
#
# 「サーバは処理したが応答がネットワークで失われた」ケースで、再送に対して
# 同じ応答を返すために要る。主キー衝突による冪等性（クライアント生成UUID）が
# 主機構で、こちらは補助。
class MutationReceipt < ApplicationRecord
  belongs_to :user

  RETENTION = 30.days

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  def self.replay(user:, key:)
    find_by(user: user, key: key)&.response
  end
end
