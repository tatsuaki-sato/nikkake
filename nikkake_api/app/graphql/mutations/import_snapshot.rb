# frozen_string_literal: true

module Mutations
  class ImportSnapshot < BaseMutation
    graphql_name "ImportSnapshot"
    argument :exercises, [ GraphQL::Types::JSON ], required: false, default_value: []
    argument :routines, [ GraphQL::Types::JSON ], required: false, default_value: []
    argument :routine_exercises, [ GraphQL::Types::JSON ], required: false, default_value: []
    argument :routine_logs, [ GraphQL::Types::JSON ], required: false, default_value: []
    argument :exercise_logs, [ GraphQL::Types::JSON ], required: false, default_value: []
    argument :client_mutation_id, String, required: false

    field :imported, Types::DataCountsType
    field :viewer, Types::ViewerType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(**args)
      payload = args.transform_values { |rows| Array(rows).map { _1.deep_symbolize_keys } }
      counts = SnapshotImporter.new(user: current_user, payload: payload).call

      ok(imported: counts, viewer: current_user)
    end
  end
end
