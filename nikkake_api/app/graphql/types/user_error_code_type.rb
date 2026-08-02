# frozen_string_literal: true

module Types
  class UserErrorCodeType < BaseEnum
    graphql_name "UserErrorCode"
    value "VALIDATION"
    value "NOT_FOUND"
    value "CONFLICT", description: "他端末で更新されていた（楽観ロック）"
    value "ALREADY_PROMOTED"
    value "INVALID_CREDENTIALS"
    value "RATE_LIMITED"
  end
end
