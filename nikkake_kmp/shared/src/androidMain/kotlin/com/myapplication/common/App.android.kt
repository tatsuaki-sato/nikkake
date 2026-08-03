package com.myapplication.common

import com.myapplication.common.data.Backend

/**
 * Android は当面ローカル実装のまま。
 * 実機からサーバへ繋ぐには localhost が使えない（エミュレータは 10.0.2.2、実機はLAN上のIP）ため、
 * ビルド構成に応じた向き先の切り替えは別途 Gradle のビルドタイプで用意する。
 */
actual val defaultBackend: Backend = Backend.LOCAL
actual val defaultApiEndpoint: String = "http://10.0.2.2:3000/graphql"
