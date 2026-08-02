# frozen_string_literal: true

class NikkakeSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  use GraphQL::Dataloader

  # 悪意ある巨大クエリでDBを引かせないための上限
  max_depth 12
  max_complexity 300
  default_max_page_size 200

  def self.unauthorized_object(_error)
    raise GraphQL::ExecutionError.new("アクセスできません", extensions: { "code" => "FORBIDDEN" })
  end

  def self.type_error(err, context)
    super
  end
end
