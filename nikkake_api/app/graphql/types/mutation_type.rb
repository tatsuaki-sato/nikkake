# frozen_string_literal: true

module Types
  class MutationType < BaseObject
    graphql_name "Mutation"

    field :create_anonymous_account, mutation: Mutations::CreateAnonymousAccount
    field :attach_email_password,    mutation: Mutations::AttachEmailPassword
    field :link_existing_account,    mutation: Mutations::LinkExistingAccount
    field :sign_out,                 mutation: Mutations::SignOut
    field :resend_verification_email, mutation: Mutations::ResendVerificationEmail

    field :create_routine,          mutation: Mutations::CreateRoutine
    field :update_routine,          mutation: Mutations::UpdateRoutine
    field :delete_routine,          mutation: Mutations::DeleteRoutine
    field :set_routine_active,      mutation: Mutations::SetRoutineActive
    field :create_custom_exercise,  mutation: Mutations::CreateCustomExercise

    field :record_workout,     mutation: Mutations::RecordWorkout
    field :delete_routine_log, mutation: Mutations::DeleteRoutineLog

    field :import_snapshot, mutation: Mutations::ImportSnapshot
    field :reset_data,      mutation: Mutations::ResetData
  end
end
