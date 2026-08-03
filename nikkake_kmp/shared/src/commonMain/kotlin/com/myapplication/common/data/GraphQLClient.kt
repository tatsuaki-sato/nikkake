package com.myapplication.common.data

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * GraphQL の呼び出し口。
 *
 * Apollo は入れていない。エンドポイントは1本で、正規化キャッシュも購読も使わないので、
 * Ktor の素の POST で足りる。依存が1つ減るぶん、
 * Kotlin / Compose のバージョン追従で壊れる余地も減る。
 */

/** ネットワークが原因の失敗。再送する価値がある */
class NetworkFailure(message: String) : Exception(message)

/** サーバが受け付けなかった。再送しても同じなので dead キューへ送る */
class PermanentFailure(message: String) : Exception(message)

/**
 * 圏外のときに保存系の画面へ出す文言。
 *
 * 端末の接続状態フラグでは判定しない。Wi-Fi に繋がっていてもサーバへ届かないことがあり、
 * 逆に「圏外」でも届くことがある。実際に送ってみた結果で判断する。
 */
const val OFFLINE_SAVE_MESSAGE = "オフラインのため保存できません。電波のあるところで試してください。"

class GraphQLClient(
    private val endpoint: String,
    private val readToken: () -> String?,
    private val httpClient: HttpClient,
    val timeZoneName: () -> String = { "Asia/Tokyo" },
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun request(query: String, variables: JsonObject = JsonObject(emptyMap())): JsonObject {
        val body = buildJsonObject {
            put("query", query)
            put("variables", variables)
        }

        val text: String
        val ok: Boolean
        val status: Int

        try {
            val response = httpClient.post(endpoint) {
                contentType(ContentType.Application.Json)
                // サーバは「今日」を計算しないが、ログと救済のためにTZは受け取る
                header("X-Nikkake-Timezone", timeZoneName())
                readToken()?.let { header("Authorization", "Bearer $it") }
                setBody(body.toString())
            }
            text = response.bodyAsText()
            ok = response.status.isSuccess()
            status = response.status.value
        } catch (e: Exception) {
            throw NetworkFailure(e.message ?: "ネットワークに接続できません")
        }

        if (!ok) {
            // 4xx は再送しても直らない。5xx は一時的な可能性がある
            if (status >= 500) throw NetworkFailure("サーバエラー ($status)")
            throw PermanentFailure("リクエストが拒否されました ($status)")
        }

        val parsed = json.parseToJsonElement(text).jsonObject

        // GraphQL は 200 で errors を返す。ここを見ないと失敗が素通りする
        parsed["errors"]?.jsonArray?.firstOrNull()?.let { first ->
            val message = first.jsonObject["message"]?.jsonPrimitive?.content
            throw PermanentFailure(message ?: "GraphQL エラー")
        }

        return parsed["data"]?.jsonObject ?: JsonObject(emptyMap())
    }
}

/** userErrors をそのまま例外に変える。message はそのまま画面に出せる日本語 */
fun JsonObject.unwrapPayload(key: String): JsonObject {
    this["userErrors"]?.jsonArray?.firstOrNull()?.let { first ->
        throw PermanentFailure(
            first.jsonObject["message"]?.jsonPrimitive?.content ?: "保存できませんでした"
        )
    }

    return this[key]?.let { it as? JsonObject } ?: throw PermanentFailure("保存できませんでした")
}

internal fun JsonElement?.str(): String? = this?.jsonPrimitive?.contentOrNullSafe()
internal fun JsonElement?.int(): Int? = this?.jsonPrimitive?.contentOrNullSafe()?.toIntOrNull()
internal fun JsonElement?.dbl(): Double? = this?.jsonPrimitive?.contentOrNullSafe()?.toDoubleOrNull()
internal fun JsonElement?.bool(): Boolean? = this?.jsonPrimitive?.contentOrNullSafe()?.toBooleanStrictOrNull()

private fun kotlinx.serialization.json.JsonPrimitive.contentOrNullSafe(): String? =
    if (this is kotlinx.serialization.json.JsonNull) null else content
