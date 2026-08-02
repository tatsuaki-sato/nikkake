# frozen_string_literal: true

# Bearer トークン（ネイティブ）と署名付き Cookie（Web）の両方を受ける。
# Web で localStorage を使わないのは XSS で抜かれるため。
module AuthenticatesRequest
  extend ActiveSupport::Concern

  private

  def current_api_token
    @current_api_token ||= ApiToken.authenticate(raw_token)
  end

  def current_user
    @current_user ||= current_api_token&.user&.tap(&:touch_last_seen!)
  end

  def raw_token
    header = request.headers["Authorization"]
    return header.split(" ", 2).last if header&.start_with?("Bearer ")

    cookies.signed[:nikkake_token]
  end
end
