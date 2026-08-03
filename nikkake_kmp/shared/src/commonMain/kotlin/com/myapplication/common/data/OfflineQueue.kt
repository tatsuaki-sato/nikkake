package com.myapplication.common.data

import com.myapplication.common.domain.nowIso
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlin.time.Duration.Companion.seconds

/**
 * オフライン記録のキュー。
 *
 * 記録だけがオフライン可（ルーティンの作成・編集はオンライン必須）。
 * id は clientMutationId としてそのままサーバへ送るので、
 * 再送しても mutation_receipts とクライアント生成UUIDの主キー衝突で吸収される。
 */
@Serializable
data class QueuedOp(
    val id: String,
    val payload: JsonObject,
    val attempts: Int = 0,
    @SerialName("next_attempt_at") val nextAttemptAt: String,
    @SerialName("last_error") val lastError: String? = null,
)

object InstantAsStringSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: Instant) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): Instant = Instant.parse(decoder.decodeString())
}

class OfflineQueue(private val db: LocalDb) {

    private val json = Json { ignoreUnknownKeys = true }
    private val listSerializer = kotlinx.serialization.builtins.ListSerializer(QueuedOp.serializer())

    companion object {
        private val MAX_BACKOFF_SECONDS = (5 * 60)
    }

    private fun read(dead: Boolean): List<QueuedOp> {
        val meta = db.getMeta()
        val raw = if (dead) meta.offlineQueueDead else meta.offlineQueue
        if (raw.isNullOrEmpty()) return emptyList()

        // 壊れたJSONで記録できなくなるのが最悪なので、握りつぶして空で復旧する
        return runCatching { json.decodeFromString(listSerializer, raw) }.getOrElse { emptyList() }
    }

    private fun write(dead: Boolean, ops: List<QueuedOp>) {
        val encoded = json.encodeToString(listSerializer, ops)
        if (dead) db.setMeta(offlineQueueDead = encoded) else db.setMeta(offlineQueue = encoded)
    }

    fun pending(): List<QueuedOp> = read(dead = false)

    /** 送信できなかったもの。設定画面に出して手動対応させる */
    fun dead(): List<QueuedOp> = read(dead = true)

    fun enqueue(id: String, payload: JsonObject) {
        val ops = pending()
        if (ops.any { it.id == id }) return

        write(dead = false, ops = ops + QueuedOp(id = id, payload = payload, nextAttemptAt = nowIso()))
    }

    /**
     * 直列に送る。失敗したら以降は次回に回して順序を守る。
     * オフライン記録は少数なので並列化する必要がない。
     */
    suspend fun flush(send: suspend (QueuedOp) -> Unit): Int {
        var sent = 0

        for (op in pending()) {
            val nextAttempt = runCatching { Instant.parse(op.nextAttemptAt) }.getOrNull()
            if (nextAttempt != null && nextAttempt > Clock.System.now()) continue

            try {
                send(op)
                remove(op.id)
                sent++
            } catch (e: PermanentFailure) {
                moveToDead(op, e.message ?: "エラー")
                break
            } catch (e: Exception) {
                backoff(op, e.message ?: "エラー")
                break
            }
        }

        return sent
    }

    private fun remove(id: String) {
        write(dead = false, ops = pending().filter { it.id != id })
    }

    private fun moveToDead(op: QueuedOp, message: String) {
        remove(op.id)
        write(dead = true, ops = dead() + op.copy(lastError = message))
    }

    private fun backoff(op: QueuedOp, message: String) {
        val attempts = op.attempts + 1
        val delaySeconds = minOf(MAX_BACKOFF_SECONDS, 1 shl op.attempts)
        val next = Clock.System.now() + delaySeconds.seconds

        write(
            dead = false,
            ops = pending().map {
                if (it.id == op.id) {
                    it.copy(attempts = attempts, nextAttemptAt = next.toString(), lastError = message)
                } else it
            },
        )
    }
}
