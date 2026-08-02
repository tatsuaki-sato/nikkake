# frozen_string_literal: true

# レート制限。
#
# このアプリは「ログイン不要で使える」ことが売りなので、
# createAnonymousAccount は無認証で叩けて、しかもDBに行を作ります。
# 裏返しとして、放置すると誰でも無制限にユーザーを量産できます。
# 無料枠のDBだとそれだけで埋まるので、公開する前に必ず有効にしてください。
#
# CAPTCHA は入れません。「ログイン不要が売り」と相性が悪く、
# 正規の初回起動を邪魔してしまうためです。
class Rack::Attack
  # カウンタの置き場は Rails.cache と分ける。
  #
  # test では null_store、production でも将来キャッシュを無効化することがあり、
  # そのとき「制限しているつもりで一度も数えていない」状態になる。
  # レート制限が黙って効かなくなるのは、あるつもりで無いぶん最悪なので、
  # 専用の MemoryStore を持たせて Rails.cache の設定から切り離す。
  #
  # インスタンスを増やしたら共有ストア（Redis など）へ移すこと。
  # プロセスごとに数えると、実効の上限がインスタンス数だけ緩む。
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  # GraphQL は単一エンドポイントなので、パスでは区別できない。
  # 本文を読んで操作名で判定する
  def self.anonymous_account_request?(request)
    return false unless request.post? && request.path == "/graphql"

    body = request.body.read
    request.body.rewind
    body.include?("createAnonymousAccount")
  rescue StandardError
    # 本文が読めないなら制限の対象外にする。
    # ここで例外を投げて正規のリクエストを落とす方が害が大きい
    false
  end

  # 上限は環境変数で上げられる。
  #
  # E2E は1テストごとに新しい匿名アカウントを作るので、
  # 既定値のままだと CI が制限に当たって落ちる。
  # 本番では **必ず既定値のまま**にすること。
  def self.limit_for(name, default)
    Integer(ENV.fetch("RATE_LIMIT_#{name}", default))
  end

  # 匿名アカウントの発行。
  #
  # 1時間に10件は、実利用ではまず超えません（普通は端末ごとに1回だけ）。
  # 家族で共有のIPや、社内NATの裏からの利用を考えても十分な余裕があります。
  throttle("匿名アカウントの発行", limit: limit_for("ANONYMOUS_ACCOUNTS", 10), period: 1.hour) do |request|
    request.ip if anonymous_account_request?(request)
  end

  # サインインの総当たり対策。
  # メールアドレスではなくIPで数える。存在するアドレスかどうかを漏らさないため
  throttle("サインイン", limit: limit_for("SIGN_IN", 20), period: 15.minutes) do |request|
    if request.post? && request.path == "/graphql"
      body = request.body.read
      request.body.rewind
      request.ip if body.include?("linkExistingAccount") || body.include?("attachEmailPassword")
    end
  rescue StandardError
    nil
  end

  # 全体の上限。壊れたクライアントが暴走したときの保険
  throttle("全体", limit: limit_for("OVERALL", 300), period: 5.minutes, &:ip)

  # 制限に当たったときは 429 と、そのまま画面に出せる日本語を返す。
  # GraphQL の形にはしない（Rack 層で止めているので resolver を通っていない）
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { errors: [ { message: "アクセスが多すぎます。しばらく待ってから試してください。",
                    extensions: { code: "RATE_LIMITED" } } ] }.to_json ]
    ]
  end
end

# テストでは無効。有効なままだと、繰り返しリクエストする spec が
# 実装の不具合ではなく制限で落ちて、原因が分かりにくくなる。
# レート制限そのものは spec/requests/rate_limit_spec.rb で個別に有効化して検証する。
Rack::Attack.enabled = !Rails.env.test?

# ミドルウェアへの挿入は rack-attack の railtie が自動で行うので、ここでは書かない。
# 明示的に use すると二重に積まれる
