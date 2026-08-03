package com.myapplication.common

import com.myapplication.common.data.Backend

/**
 * iOS は当面ローカル実装のまま。
 * シミュレータは localhost が使えるが、実機はLAN上のIPが要る。
 * ビルド構成に応じた向き先の切り替えは別途用意する。
 */
actual val defaultBackend: Backend = Backend.LOCAL
actual val defaultApiEndpoint: String = "http://127.0.0.1:3000/graphql"
