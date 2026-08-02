# frozen_string_literal: true

require "rails_helper"

# レート制限。
#
# 他の spec では Rack::Attack を無効にしている（繰り返しリクエストする spec が
# 実装の不具合ではなく制限で落ちると原因が分かりにくいため）。
# ここだけ明示的に有効にして検証する。
#
# 確かめたいのは2つ。
#   1. 無制限に匿名アカウントを作れないこと（公開したときにDBが埋まらない）
#   2. 正規の利用を邪魔しないこと（記録や参照は制限に当たらない）
RSpec.describe "レート制限", type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.reset!
  end

  let(:create_account) do
    <<~GQL
      mutation { createAnonymousAccount(timeZone: "Asia/Tokyo") { token userErrors { message } } }
    GQL
  end

  def post_graphql(query, headers: {})
    post "/graphql", params: { query: query }.to_json,
                     headers: { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  describe "匿名アカウントの発行" do
    it "1時間に10件までは通る" do
      10.times do
        post_graphql(create_account)
        expect(response).to have_http_status(:ok)
      end
    end

    it "11件目は429で断り、そのまま画面に出せる日本語を返す" do
      11.times { post_graphql(create_account) }

      expect(response).to have_http_status(:too_many_requests)

      body = JSON.parse(response.body)
      expect(body.dig("errors", 0, "message")).to eq("アクセスが多すぎます。しばらく待ってから試してください。")
      expect(body.dig("errors", 0, "extensions", "code")).to eq("RATE_LIMITED")
      expect(response.headers["Retry-After"]).to be_present
    end

    it "IPが違えば別々に数える" do
      11.times { post_graphql(create_account, headers: { "REMOTE_ADDR" => "10.0.0.1" }) }
      expect(response).to have_http_status(:too_many_requests)

      post_graphql(create_account, headers: { "REMOTE_ADDR" => "10.0.0.2" })
      expect(response).to have_http_status(:ok)
    end
  end

  describe "正規の利用" do
    let(:user) { User.create!(time_zone: "Asia/Tokyo") }
    let(:raw_token) { ApiToken.issue!(user).last }

    it "参照は匿名アカウントの制限に当たらない" do
      # 発行の上限（10）を超える回数を叩いても、別の操作なら通る
      15.times do
        post_graphql("{ exercises { id } }",
                     headers: { "HTTP_AUTHORIZATION" => "Bearer #{raw_token}" })
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "サインインの総当たり" do
    it "20回を超えると断る" do
      query = <<~GQL
        mutation { linkExistingAccount(email: "a@example.com", password: "x", mergeAnonymousData: false) {
          token userErrors { message } } }
      GQL

      21.times { post_graphql(query) }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
