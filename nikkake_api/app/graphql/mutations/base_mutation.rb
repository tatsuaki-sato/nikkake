# frozen_string_literal: true

module Mutations
  # 冪等性をここで一括処理する。
  #
  # 主機構はクライアント生成 UUID の主キー衝突（再送しても同じ id なので二重登録されない）。
  # こちらは「サーバは処理したが応答がネットワークで失われた」ケースで
  # 同じ応答を返すための補助。
  class BaseMutation < GraphQL::Schema::Mutation
    def resolve(**args)
      key = args.delete(:client_mutation_id)
      return perform(**args) if key.blank?

      if (cached = MutationReceipt.replay(user: current_user, key: key))
        return cached.deep_symbolize_keys
      end

      result = perform(**args)
      save_receipt(key, result)
      result
    rescue ActiveRecord::RecordNotUnique
      # 同一キーの並行リクエスト。相手が書いたものを返す
      MutationReceipt.replay(user: current_user, key: key)&.deep_symbolize_keys || result
    end

    private

    def perform(**)
      raise NotImplementedError
    end

    def current_user
      context[:current_user] or
        raise GraphQL::ExecutionError.new("認証が必要です", extensions: { "code" => "UNAUTHENTICATED" })
    end

    # レシートは JSON にできる範囲だけ保存する。
    # ActiveRecord を含む応答はリプレイ対象にしない（次回は再実行される）。
    def save_receipt(key, result)
      return unless result.is_a?(Hash) && result.values.none? { _1.is_a?(ActiveRecord::Base) }

      MutationReceipt.create!(
        user: current_user, key: key,
        mutation: self.class.graphql_name, response: result.as_json, created_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def user_error(message, code:, path: nil)
      { path: path, message: message, code: code }
    end

    def ok(extra = {}) = extra.merge(user_errors: [])
    def ng(*errors) = { user_errors: errors }
  end
end
