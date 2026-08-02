# frozen_string_literal: true

module Mutations
  class ResetData < BaseMutation
    graphql_name "ResetData"
    field :success, Boolean, null: false
    field :user_errors, [ Types::UserErrorType ], null: false

    # クラウド側のこのユーザーのデータを消す。プリセット種目は共有マスタなので残す
    def perform
      ActiveRecord::Base.transaction do
        current_user.exercise_logs.delete_all
        current_user.routine_logs.delete_all
        current_user.routine_exercises.delete_all
        current_user.routines.delete_all
      end
      ok(success: true)
    end
  end
end
