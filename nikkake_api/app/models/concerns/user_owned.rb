# frozen_string_literal: true

# 所有者が明確なレコードの共通の振る舞い。
#
# user_id を全テーブルに非正規化してあるので、必ず current_user から
# association を辿れば他人のデータには到達しない。
# spec/architecture_spec.rb がモデルクラスからの直接 find を禁止している。
module UserOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :user

    # 論理削除。物理削除にすると、オフラインキューが持っている
    # 削除済みルーティンへの記録が FK 違反で永久に送信失敗する。
    scope :kept, -> { where(deleted_at: nil) }
    scope :changed_since, ->(cursor) { cursor ? where(arel_table[:updated_at].gt(cursor)) : all }
  end

  def deleted? = deleted_at.present?

  def soft_delete!
    update!(deleted_at: Time.current) unless deleted?
  end
end
