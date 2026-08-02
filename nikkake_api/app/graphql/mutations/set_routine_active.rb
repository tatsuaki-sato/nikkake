# frozen_string_literal: true

module Mutations
  class SetRoutineActive < BaseMutation
    graphql_name "SetRoutineActive"
    argument :id, ID
    argument :is_active, Boolean
    argument :client_mutation_id, String, required: false

    field :routine, Types::RoutineType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(id:, is_active:)
      routine = current_user.routines.kept.find_by(id: id)
      return ng(user_error("見つかりません", code: "NOT_FOUND")) unless routine

      routine.update!(is_active: is_active)
      ok(routine: routine)
    end
  end
end
