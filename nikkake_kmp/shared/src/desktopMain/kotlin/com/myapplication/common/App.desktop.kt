package com.myapplication.common

import com.myapplication.common.data.Backend

/**
 * デスクトップは JVM のシステムプロパティで切り替える。
 *
 *   ./gradlew :desktopApp:run -Dnikkake.backend=server -Dnikkake.endpoint=http://127.0.0.1:3000/graphql
 *
 * 未指定なら local（端末のみ、ネットワーク不使用）で動く。
 */
actual val defaultBackend: Backend =
    if (System.getProperty("nikkake.backend") == "server") Backend.SERVER else Backend.LOCAL

// 127.0.0.1 を既定にする理由: localhost だと環境によって ::1 に解決され、
// IPv4 だけで待っている Rails に届かないことがある
actual val defaultApiEndpoint: String =
    System.getProperty("nikkake.endpoint") ?: "http://127.0.0.1:3000/graphql"
