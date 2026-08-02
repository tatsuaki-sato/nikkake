# frozen_string_literal: true

module Mutations
  class SignOut < BaseMutation
    graphql_name "SignOut"
    field :success, Boolean, null: false
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform
      context[:api_token]&.revoke!
      ok(success: true)
    end
  end
end
