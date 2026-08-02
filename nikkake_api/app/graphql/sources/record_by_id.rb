# frozen_string_literal: true

module Sources
  # 単一レコードのまとめ読み。N+1 を潰す
  class RecordById < GraphQL::Dataloader::Source
    def initialize(model) = @model = model

    def fetch(ids)
      found = @model.where(id: ids).index_by(&:id)
      ids.map { found[_1] }
    end
  end
end
