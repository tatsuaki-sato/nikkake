# frozen_string_literal: true

module Types
  class DateTimeType < BaseScalar
    graphql_name "DateTime"
    description "ISO8601 (UTC)"

    def self.coerce_input(value, _ctx)
      Time.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      raise GraphQL::CoercionError, "#{value.inspect} は ISO8601 形式ではありません"
    end

    def self.coerce_result(value, _ctx)
      value.is_a?(String) ? value : value.utc.iso8601
    end
  end
end
