# frozen_string_literal: true

module Mutations
  class ResendVerificationEmail < BaseMutation
    graphql_name "ResendVerificationEmail"
    field :success, Boolean, null: false
    field :user_errors, [ Types::UserErrorType ], null: false

    # メール送信基盤は未選定。導線だけ先に用意しておく
    def perform
      ok(success: true)
    end
  end
end
