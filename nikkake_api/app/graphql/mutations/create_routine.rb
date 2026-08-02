# frozen_string_literal: true

module Mutations
  class CreateRoutine < BaseMutation
    graphql_name "CreateRoutine"
    include RoutineValidation
    argument :id, ID
    include RoutineArguments

    def perform(**args)
      error = validate(name: args[:name], exercises: args[:exercises],
                       frequency_type: args[:frequency_type], frequency_days: args[:frequency_days])
      return ng(error) if error

      routine = RoutineWriter.new(user: current_user).create(normalize(args))
      ok(routine: routine)
    end

    private

    def normalize(args)
      args.merge(exercises: args[:exercises].map(&:to_h))
    end
  end
end
