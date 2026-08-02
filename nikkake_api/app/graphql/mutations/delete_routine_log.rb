# frozen_string_literal: true

module Mutations
  class DeleteRoutineLog < BaseMutation
    graphql_name "DeleteRoutineLog"
    argument :id, ID
    argument :client_mutation_id, String, required: false

    field :success, Boolean, null: false
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(id:)
      log = current_user.routine_logs.kept.find_by(id: id)
      return ng(user_error("見つかりません", code: "NOT_FOUND")).merge(success: false) unless log

      ActiveRecord::Base.transaction do
        log.exercise_logs.kept.find_each(&:soft_delete!)
        log.soft_delete!
      end
      ok(success: true)
    end
  end

  # 遅延登録の本体。端末ローカルのデータをまるごと取り込む
end
