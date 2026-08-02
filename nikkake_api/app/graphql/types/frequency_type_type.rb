# frozen_string_literal: true

module Types
  class FrequencyTypeType < BaseEnum
    graphql_name "FrequencyType"
    value "DAILY",        value: "daily"
    value "EVERY_N_DAYS", value: "every_n_days"
    value "WEEKLY",       value: "weekly"
  end
end
