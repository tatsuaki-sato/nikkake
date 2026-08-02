# frozen_string_literal: true

module Sources
  # 論理削除されていない子レコードのまとめ読み
  class KeptByForeignKey < GraphQL::Dataloader::Source
    def initialize(model, foreign_key)
      @model = model
      @foreign_key = foreign_key
    end

    def fetch(keys)
      grouped = @model.kept.where(@foreign_key => keys).group_by { _1.public_send(@foreign_key) }
      keys.map { grouped[_1] || [] }
    end
  end
end
