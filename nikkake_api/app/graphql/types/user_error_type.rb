# frozen_string_literal: true

module Types
  class UserErrorType < BaseObject
    graphql_name "UserError"
    description "入力起因のエラー。message はそのまま画面に出せる日本語"
    field :path, [ String ]
    field :message, String, null: false
    field :code, UserErrorCodeType, null: false
  end
end
