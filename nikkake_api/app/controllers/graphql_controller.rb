# frozen_string_literal: true

# 唯一のエンドポイント。
#
# 「今日」はここでも計算しない。クライアントが today 引数で送ってくる。
# タイムゾーンはリクエストヘッダを優先し、無ければユーザー設定にフォールバックする
# （バッチ処理用の保険であり、判定には常にリクエストの値を使う）。
class GraphqlController < ApplicationController
  include AuthenticatesRequest

  def execute
    result = NikkakeSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: {
        current_user: current_user,
        api_token: current_api_token,
        time_zone: request_time_zone,
        request_id: request.request_id
      }
    )
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development? || Rails.env.test?

    render json: {
      errors: [ { message: e.message, backtrace: e.backtrace&.first(10) } ], data: {}
    }, status: :internal_server_error
  end

  private

  def request_time_zone
    candidate = request.headers["X-Nikkake-Timezone"].presence || current_user&.time_zone
    ActiveSupport::TimeZone[candidate.to_s] ? candidate : "Asia/Tokyo"
  end

  # ActionController::Parameters のままだと JSON スカラーの中身が
  # Parameters として渡り、graphql-ruby 側で解決できない。素の Hash に落とす。
  def prepare_variables(raw)
    case raw
    when String then raw.present? ? (JSON.parse(raw) || {}) : {}
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    when nil then {}
    else raise ArgumentError, "variables の形式が不正です: #{raw}"
    end
  end
end
