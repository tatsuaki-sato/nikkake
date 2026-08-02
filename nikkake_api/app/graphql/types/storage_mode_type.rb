# frozen_string_literal: true

module Types
  class StorageModeType < BaseEnum
    graphql_name "StorageMode"
    value "LOCAL_ONLY", description: "サーバ未登録。遅延登録が完了するまでの一時状態"
    value "CLOUD"
  end
end
