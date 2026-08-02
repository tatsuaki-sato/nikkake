# frozen_string_literal: true

# 匿名アカウント先行のユーザー。
#
# 初回起動時に「メールアドレスの無いユーザー」として作られ、あとから
# attach_email_password! で昇格する。id が変わらないのでデータ移行は発生しない。
# 移行前の claimLocalRows（user_id = null のレコードを引き取る処理）が丸ごと不要になった。
#
# Devise / Rodauth を使っていないのは、どちらも「アカウント = メールアドレス」を
# 前提にしており、匿名先行と噛み合わないため。ダミーメールを詰めると
# 偽データが制約・メール送信・昇格処理の全てに漏れ出す。
# 暗号自体は書いておらず、has_secure_password / authenticate_by は Rails 本体の API。
class User < ApplicationRecord
  has_secure_password validations: false

  has_many :api_tokens, dependent: :destroy
  has_many :routines, dependent: :destroy
  has_many :routine_exercises, dependent: :destroy
  has_many :routine_logs, dependent: :destroy
  has_many :exercise_logs, dependent: :destroy
  has_many :custom_exercises, class_name: "Exercise", foreign_key: :created_by_id, dependent: :nullify,
                              inverse_of: :created_by

  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                    if: -> { email.present? }

  scope :anonymous, -> { where(email: nil) }

  def anonymous? = email.nil?
  def email_verified? = email_verified_at.present?

  # 匿名 → メール登録の昇格。id は変わらないのでデータは1件も動かない
  def attach_email_password!(email:, password:, display_name: nil)
    raise AlreadyPromoted unless anonymous?

    update!(email: email, password: password, display_name: display_name)
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end

  class AlreadyPromoted < StandardError; end
end
