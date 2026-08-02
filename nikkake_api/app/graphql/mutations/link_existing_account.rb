# frozen_string_literal: true

module Mutations
  class LinkExistingAccount < BaseMutation
    graphql_name "LinkExistingAccount"
    argument :email, String
    argument :password, String
    argument :merge_anonymous_data, Boolean
    argument :client_mutation_id, String, required: false

    field :token, String
    field :viewer, Types::ViewerType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(email:, password:, merge_anonymous_data:)
      target = User.authenticate_by(email: email, password: password)
      unless target
        return ng(user_error("メールアドレスまたはパスワードが違います", code: "INVALID_CREDENTIALS"))
      end

      anonymous = context[:current_user]
      if anonymous&.anonymous? && anonymous.id != target.id
        merge_anonymous_data ? merge!(anonymous, target) : anonymous.destroy
      end

      _token, raw = ApiToken.issue!(target)
      { token: raw, viewer: target, user_errors: [] }
    end

    private

    # 匿名ユーザーのレコードを既存アカウントへ付け替える
    def merge!(anonymous, target)
      ActiveRecord::Base.transaction do
        %i[routines routine_exercises routine_logs exercise_logs].each do
          anonymous.public_send(_1).update_all(user_id: target.id, updated_at: Time.current)
        end
        anonymous.reload.destroy
      end
    end

    def current_user = context[:current_user]
    def save_receipt(_key, _result) = nil
  end
end
