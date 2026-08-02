# frozen_string_literal: true

module Types
  class LogStatusType < BaseEnum
    graphql_name "LogStatus"
    value "COMPLETED", value: "completed"
    value "PARTIAL",   value: "partial"
    value "SKIPPED",   value: "skipped"
  end
end
