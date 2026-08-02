# frozen_string_literal: true

module Mutations
  class DeleteRoutine < BaseMutation
    graphql_name "DeleteRoutine"
    argument :id, ID
    argument :client_mutation_id, String, required: false

    field :routine, Types::RoutineType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(id:)
      routine = current_user.routines.kept.find_by(id: id)
      return ng(user_error("見つかりません", code: "NOT_FOUND")) unless routine

      ok(routine: RoutineWriter.new(user: current_user).delete(routine))
    end
  end
end
