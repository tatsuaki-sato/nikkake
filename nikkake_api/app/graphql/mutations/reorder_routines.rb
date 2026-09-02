# frozen_string_literal: true

module Mutations
  # ホームでの並び順を入れ替える。渡された順番がそのままsort_orderになる。
  class ReorderRoutines < BaseMutation
    graphql_name "ReorderRoutines"
    argument :routine_ids, [ ID ]
    argument :client_mutation_id, String, required: false

    field :routines, [ Types::RoutineType ]
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(routine_ids:)
      routines = current_user.routines.kept.where(id: routine_ids).index_by(&:id)
      return ng(user_error("見つかりません", code: "NOT_FOUND")) if routines.size != routine_ids.size

      ActiveRecord::Base.transaction do
        routine_ids.each_with_index do |id, index|
          routines[id].update!(sort_order: index)
        end
      end

      ok(routines: routines.values_at(*routine_ids))
    end
  end
end
