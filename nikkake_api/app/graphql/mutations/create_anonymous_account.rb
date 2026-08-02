# frozen_string_literal: true

module Mutations
  class CreateAnonymousAccount < BaseMutation
    graphql_name "CreateAnonymousAccount"
    argument :time_zone, String
    argument :device_label, String, required: false
    # Web はローカルシードを持たないのでサーバ側で初期ルーティンを作る。
    # ネイティブは端末でシードしてから importSnapshot するので false を渡す。
    argument :with_starter_routine, Boolean, required: false, default_value: true
    argument :client_mutation_id, String, required: false

    field :token, String, description: "Bearer トークン。Web は httpOnly Cookie に載せる"
    field :viewer, Types::ViewerType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(time_zone:, device_label: nil, with_starter_routine: true)
      result = AccountCreator.call(time_zone: time_zone, device_label: device_label)
      StarterRoutineBuilder.call(user: result.user) if with_starter_routine

      { token: result.raw_token, viewer: result.user, user_errors: [] }
    end

    # 認証前なので current_user が無い。レシートも残さない
    def current_user = context[:current_user]
    def save_receipt(_key, _result) = nil
  end

  # 匿名 → メール登録の昇格。user.id は変わらないのでデータ移行は発生しない
end
