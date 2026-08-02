# frozen_string_literal: true

module Types
  # 'YYYY-MM-DD'。端末のローカル日付をそのまま運ぶ。
  # サーバが UTC から導出すると1日ずれるので、文字列のまま受け渡す。
  class DateType < BaseScalar
    graphql_name "Date"
    description "YYYY-MM-DD。端末のローカル日付。サーバは UTC から導出しない"

    def self.coerce_input(value, _ctx)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise GraphQL::CoercionError, "#{value.inspect} は YYYY-MM-DD 形式ではありません"
    end

    def self.coerce_result(value, _ctx)
      value.is_a?(String) ? value : value.strftime("%Y-%m-%d")
    end
  end
end
