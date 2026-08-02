# frozen_string_literal: true

module Mutations
  class UpdateRoutine < BaseMutation
    graphql_name "UpdateRoutine"
    include RoutineValidation
    argument :id, ID
    argument :is_active, Boolean, required: false, default_value: true
    argument :lock_version, Integer
    include RoutineArguments

    def perform(**args)
      error = validate(name: args[:name], exercises: args[:exercises],
                       frequency_type: args[:frequency_type], frequency_days: args[:frequency_days])
      return ng(error) if error

      routine = current_user.routines.kept.find_by(id: args[:id])
      return ng(user_error("見つかりません", code: "NOT_FOUND")) unless routine

      updated = RoutineWriter.new(user: current_user)
                             .update(routine, args.merge(exercises: args[:exercises].map(&:to_h)))
      ok(routine: updated)
    rescue RoutineWriter::Conflict
      ng(user_error("他の端末で更新されています。読み込み直してください", code: "CONFLICT"))
    end
  end
end
