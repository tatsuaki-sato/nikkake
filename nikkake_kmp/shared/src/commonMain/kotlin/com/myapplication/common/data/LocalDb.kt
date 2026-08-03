package com.myapplication.common.data

import com.myapplication.common.domain.nowIso
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlin.random.Random

/**
 * ローカルの「テーブル」名。Rails 側の列名(snake_case)と1:1で対応させてあるので、
 * 同期処理は名前をそのまま使ってpush/pullできる。
 */
object Collections {
    const val EXERCISES = "exercises"
    const val ROUTINES = "routines"
    const val ROUTINE_EXERCISES = "routine_exercises"
    const val ROUTINE_LOGS = "routine_logs"
    const val EXERCISE_LOGS = "exercise_logs"

    /** 親→子の順。外部キー制約を壊さないためにこの順でpushする */
    val all = listOf(EXERCISES, ROUTINES, ROUTINE_EXERCISES, ROUTINE_LOGS, EXERCISE_LOGS)
}

@Serializable
data class LocalMeta(
    val schemaVersion: Int = LocalDb.CURRENT_SCHEMA_VERSION,
    val seeded: Boolean = false,
    /**
     * サーバが発行したトークン。生の値はここにしか無い。
     * サインアウトで空文字を入れるので、読むときは空を null と同じに扱う（apiToken プロパティ側で吸収）
     */
    @SerialName("api_token") private val apiTokenRaw: String? = null,
    /**
     * 端末のデータをサーバへ預けた日時。
     * 一度入ったら二度と送らない。繰り返すとサーバで消したルーティンが復活する
     */
    @SerialName("snapshot_imported_at") val snapshotImportedAt: String? = null,
    /** 送信待ちの記録（JSON文字列） */
    @SerialName("offline_queue") val offlineQueue: String? = null,
    /** 送信を諦めた記録。設定画面に出して手動対応させる */
    @SerialName("offline_queue_dead") val offlineQueueDead: String? = null,
) {
    val apiToken: String? get() = apiTokenRaw?.takeIf { it.isNotEmpty() }

    /** LocalMeta.copy() を直接使うと private フィールド名が露出するので、これ経由にする */
    fun withApiToken(value: String?) = copy(apiTokenRaw = value)
}

/** クライアント生成のIDは PostgreSQL の uuid 列に入るので、RFC 4122 v4 準拠にする */
object Uuid {
    private const val HEX = "0123456789abcdef"

    fun v4(random: Random = Random.Default): String {
        val bytes = ByteArray(16) { random.nextInt(256).toByte() }
        bytes[6] = ((bytes[6].toInt() and 0x0f) or 0x40).toByte()
        bytes[8] = ((bytes[8].toInt() and 0x3f) or 0x80).toByte()

        val hex = bytes.joinToString("") { b ->
            val v = b.toInt() and 0xff
            "${HEX[v shr 4]}${HEX[v and 0x0f]}"
        }

        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
            "${hex.substring(16, 20)}-${hex.substring(20, 32)}"
    }
}

/**
 * 端末ローカルのJSONコレクション置き場。
 *
 * 画面描画のたびにデコードすると重いので、読み込んだコレクションは
 * メモリにキャッシュし、書き込み時に両方を更新する。
 */
class LocalDb(private val storage: StorageAdapter) {

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
        const val PREFIX = "nikkake:v1:"
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val cache = mutableMapOf<String, List<*>>()

    private fun key(name: String) = "$PREFIX$name"

    // ------------------------------------------
    // メタ情報
    // ------------------------------------------

    fun getMeta(): LocalMeta {
        val raw = storage.getString(key("meta")) ?: return LocalMeta()
        return runCatching { json.decodeFromString(LocalMeta.serializer(), raw) }.getOrElse { LocalMeta() }
    }

    fun setMeta(
        seeded: Boolean? = null,
        apiToken: String? = null,
        snapshotImportedAt: String? = null,
        offlineQueue: String? = null,
        offlineQueueDead: String? = null,
    ): LocalMeta {
        val current = getMeta()
        val next = current.copy(
            seeded = seeded ?: current.seeded,
            snapshotImportedAt = snapshotImportedAt ?: current.snapshotImportedAt,
            offlineQueue = offlineQueue ?: current.offlineQueue,
            offlineQueueDead = offlineQueueDead ?: current.offlineQueueDead,
        ).let { if (apiToken != null) it.withApiToken(apiToken) else it }
        storage.putString(key("meta"), json.encodeToString(LocalMeta.serializer(), next))
        return next
    }

    // ------------------------------------------
    // コレクション操作
    // ------------------------------------------

    @Suppress("UNCHECKED_CAST")
    fun <T : SyncEntity<T>> readRaw(name: String, serializer: KSerializer<T>): List<T> {
        cache[name]?.let { return it as List<T> }

        val raw = storage.getString(key(name))
        if (raw == null) {
            cache[name] = emptyList<T>()
            return emptyList()
        }

        // 壊れたJSONで起動不能になるのが最悪なので、握りつぶして空で復旧する
        val rows = runCatching { json.decodeFromString(ListSerializer(serializer), raw) }
            .getOrElse { emptyList() }

        cache[name] = rows
        return rows
    }

    fun <T : SyncEntity<T>> write(name: String, serializer: KSerializer<T>, rows: List<T>) {
        cache[name] = rows
        storage.putString(key(name), json.encodeToString(ListSerializer(serializer), rows))
    }

    /** 論理削除されていない行だけ */
    fun <T : SyncEntity<T>> list(name: String, serializer: KSerializer<T>): List<T> =
        readRaw(name, serializer).filter { it.deletedAt == null }

    fun <T : SyncEntity<T>> find(name: String, serializer: KSerializer<T>, id: String): T? =
        list(name, serializer).firstOrNull { it.id == id }

    fun <T : SyncEntity<T>> insert(name: String, serializer: KSerializer<T>, row: T): T {
        val stamped = row.touched(updatedAt = nowIso(), deletedAt = null)
        write(name, serializer, readRaw(name, serializer) + stamped)
        return stamped
    }

    fun <T : SyncEntity<T>> insertMany(name: String, serializer: KSerializer<T>, rows: List<T>): List<T> {
        if (rows.isEmpty()) return emptyList()

        val timestamp = nowIso()
        val stamped = rows.map { it.touched(updatedAt = timestamp, deletedAt = null) }
        write(name, serializer, readRaw(name, serializer) + stamped)
        return stamped
    }

    /** 既存行を transform で書き換える。updated_at は自動で進める */
    fun <T : SyncEntity<T>> update(
        name: String,
        serializer: KSerializer<T>,
        id: String,
        transform: (T) -> T,
    ): T? {
        val rows = readRaw(name, serializer)
        val index = rows.indexOfFirst { it.id == id }
        if (index < 0) return null

        val updated = transform(rows[index]).touched(updatedAt = nowIso())
        write(name, serializer, rows.toMutableList().also { it[index] = updated })
        return updated
    }

    /**
     * 論理削除。物理削除にすると「削除した」という事実が同期先に伝わらず、
     * 他端末からpullし直すたびに復活してしまう。
     */
    fun <T : SyncEntity<T>> softDelete(name: String, serializer: KSerializer<T>, id: String): Boolean {
        val rows = readRaw(name, serializer)
        val index = rows.indexOfFirst { it.id == id }
        if (index < 0) return false

        val timestamp = nowIso()
        val deleted = rows[index].touched(updatedAt = timestamp, deletedAt = timestamp)
        write(name, serializer, rows.toMutableList().also { it[index] = deleted })
        return true
    }

    fun <T : SyncEntity<T>> softDeleteWhere(
        name: String,
        serializer: KSerializer<T>,
        predicate: (T) -> Boolean,
    ): Int {
        val rows = readRaw(name, serializer)
        val timestamp = nowIso()
        var count = 0

        val next = rows.map { row ->
            if (row.deletedAt != null || !predicate(row)) row
            else {
                count++
                row.touched(updatedAt = timestamp, deletedAt = timestamp)
            }
        }

        if (count > 0) write(name, serializer, next)
        return count
    }

    fun reset() {
        storage.keys().filter { it.startsWith(PREFIX) }.forEach(storage::remove)
        cache.clear()
    }
}
