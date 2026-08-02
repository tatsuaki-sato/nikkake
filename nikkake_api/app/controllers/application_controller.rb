class ApplicationController < ActionController::API
  # Web は httpOnly Cookie、ネイティブは Bearer トークンで認証する
  include ActionController::Cookies
end
