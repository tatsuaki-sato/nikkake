# frozen_string_literal: true

# ブラウザから直接叩かれるのは開発時の Expo Web だけ。
# 本番の Web は Vite / 配信元が同一オリジンでプロキシするので CORS は要らない。
# ネイティブ（RN / Flutter / KMP）はブラウザではないので無関係。
#
# 許可オリジンは環境変数で明示する。ワイルドカードにはしない。
# credentials: true と "*" は併用できないうえ、
# トークンを Cookie で持つ経路がある以上、緩めると素通しになる。
allowed = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

if allowed.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed)
      resource "/graphql", headers: :any, methods: [ :post, :options ], credentials: true
    end
  end
end
