# frozen_string_literal: true

module Mutations
  class AttachEmailPassword < BaseMutation
    graphql_name "AttachEmailPassword"
    argument :email, String
    argument :password, String
    argument :display_name, String, required: false
    argument :client_mutation_id, String, required: false

    field :token, String
    field :viewer, Types::ViewerType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(email:, password:, display_name: nil)
      if password.to_s.length < 6
        return ng(user_error("パスワードは6文字以上にしてください", code: "VALIDATION", path: [ "password" ]))
      end

      current_user.attach_email_password!(email: email, password: password, display_name: display_name)
      { token: nil, viewer: current_user, user_errors: [] }
    rescue User::AlreadyPromoted
      ng(user_error("このアカウントは既に登録済みです", code: "ALREADY_PROMOTED"))
    rescue ActiveRecord::RecordInvalid
      ng(user_error("このメールアドレスは既に使われています", code: "VALIDATION", path: [ "email" ]))
    end
  end

  # 既存アカウントへのサインイン。この端末の匿名データを統合するか選べる
end
