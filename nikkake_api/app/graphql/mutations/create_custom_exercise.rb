# frozen_string_literal: true

module Mutations
  class CreateCustomExercise < BaseMutation
    graphql_name "CreateCustomExercise"
    argument :id, ID
    argument :name, String
    argument :category, Types::ExerciseCategoryType
    argument :icon, String, required: false
    argument :client_mutation_id, String, required: false

    field :exercise, Types::ExerciseType
    field :user_errors, [ Types::UserErrorType ], null: false

    def perform(id:, name:, category:, icon: nil)
      return ng(user_error("種目名を入力してください", code: "VALIDATION", path: [ "name" ])) if name.blank?

      exercise = Exercise.create!(
        id: id, name: name, category: category, icon: icon,
        is_preset: false, created_by: current_user
      )
      ok(exercise: exercise)
    end
  end
end
