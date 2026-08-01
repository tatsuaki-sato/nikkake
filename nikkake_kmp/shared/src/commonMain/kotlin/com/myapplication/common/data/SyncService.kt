package com.myapplication.common.data

import com.myapplication.common.domain.nowIso
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Supabaseとの同期。
 *
 * 方針:
 *  - ローカルが常に真実の源。同期はあくまで「バックアップと他端末への複製」
 *  - 衝突は updated_at の新しい方を採用する (last-write-wins)
 *  - 失敗しても画面は動き続ける。次回の同期でリトライされる
 *
 * サインインしていない場合、この層は一切呼ばれない。
 *
 * postgrest の API は reified な型引数を要求するため、テーブルごとに型付き関数を
 * 並べる代わりに JsonObject を経由している。こうするとコレクション名と
 * シリアライザのペアをループで回せて、テーブルが増えても書き足す場所が1か所で済む。
 */
class SyncException(message: String, val collection: String? = null) : Exception(message)

data class SyncResult(val pushed: Int, val pulled: Int, val syncedAt: String)

class SyncService(val db: LocalDb, private val client: SupabaseClient) {

    /** ユーザーに紐づくテーブル。pull時に user_id で絞り込む */
    private val userScoped = setOf(Collections.ROUTINES, Collections.ROUTINE_LOGS)

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    /**
     * 同期対象のテーブル一覧。親→子の順に並べてあり、この順でpushすることで
     * 外部キー制約に引っかからないようにしている。
     */
    private val tables: List<Table<*>> = listOf(
        // プリセット種目はサーバ側にも同じIDで存在する共有マスタなので送らない
        Table(Collections.EXERCISES, Exercise.serializer()) { !it.isPreset },
        Table(Collections.ROUTINES, Routine.serializer()),
        Table(Collections.ROUTINE_EXERCISES, RoutineExercise.serializer()),
        Table(Collections.ROUTINE_LOGS, RoutineLog.serializer()),
        Table(Collections.EXERCISE_LOGS, ExerciseLog.serializer()),
    )

    private class Table<T : SyncEntity<T>>(
        val name: String,
        val serializer: KSerializer<T>,
        val pushFilter: (T) -> Boolean = { true },
    )

    /**
     * サインイン直後に一度だけ実行する。
     * それまで user_id = null で作られていたローカルのレコードを、
     * このアカウントのものとして引き取る。
     */
    fun claimLocalRows(userId: String): Int {
        val timestamp = nowIso()
        var claimed = 0

        val routines = db.readRaw(Collections.ROUTINES, Routine.serializer())
        val nextRoutines = routines.map {
            if (it.userId == userId) it else {
                claimed++
                it.copy(userId = userId, updatedAt = timestamp)
            }
        }
        if (nextRoutines != routines) db.write(Collections.ROUTINES, Routine.serializer(), nextRoutines)

        val logs = db.readRaw(Collections.ROUTINE_LOGS, RoutineLog.serializer())
        val nextLogs = logs.map {
            if (it.userId == userId) it else {
                claimed++
                it.copy(userId = userId, updatedAt = timestamp)
            }
        }
        if (nextLogs != logs) db.write(Collections.ROUTINE_LOGS, RoutineLog.serializer(), nextLogs)

        return claimed
    }

    private fun <T : SyncEntity<T>> pendingRows(table: Table<T>, since: String?): List<T> =
        db.changedSince(table.name, table.serializer, since).filter(table.pushFilter)

    private suspend fun <T : SyncEntity<T>> push(table: Table<T>, since: String?): Int {
        val rows = pendingRows(table, since)
        if (rows.isEmpty()) return 0

        // ListSerializer でJSONへ落としてから送る。postgrest 側の reified 型引数は
        // JsonObject で固定できるので、テーブルごとの分岐が要らなくなる。
        val payload = json.decodeFromString(
            ListSerializer(JsonObject.serializer()),
            json.encodeToString(ListSerializer(table.serializer), rows),
        )

        try {
            client.postgrest[table.name].upsert(payload, onConflict = "id")
        } catch (e: Exception) {
            throw SyncException(e.message ?: "upsert failed", table.name)
        }
        return rows.size
    }

    private suspend fun <T : SyncEntity<T>> pull(table: Table<T>, since: String?, userId: String): Int {
        val remote = try {
            client.postgrest[table.name].select {
                filter {
                    if (since != null) gt("updated_at", since)
                    if (table.name in userScoped) eq("user_id", userId)
                }
            }.decodeList<JsonObject>()
        } catch (e: Exception) {
            throw SyncException(e.message ?: "select failed", table.name)
        }

        if (remote.isEmpty()) return 0

        val rows = json.decodeFromString(
            ListSerializer(table.serializer),
            json.encodeToString(ListSerializer(JsonObject.serializer()), remote),
        )

        val result = db.upsertFromRemote(table.name, table.serializer, rows)
        return result.inserted + result.updated
    }

    /**
     * 双方向同期を1回実行する。
     *
     * pushを先にやるのは、同じレコードを両方が持っていた場合に
     * サーバ側の updated_at が確定してからpullしたいため。
     */
    suspend fun runSync(userId: String): SyncResult {
        val meta = db.getMeta()

        // 別アカウントでサインインし直した場合は差分カーソルを捨てて全件取り直す
        val since = if (meta.syncUserId == userId) meta.lastSyncedAt else null

        // 処理中に増えた変更を取りこぼさないよう、完了時刻ではなく開始時刻をカーソルにする
        val startedAt = nowIso()

        var pushed = 0
        for (table in tables) pushed += push(table, since)

        var pulled = 0
        for (table in tables) pulled += pull(table, since, userId)

        db.setMeta(lastSyncedAt = startedAt, syncUserId = userId)
        return SyncResult(pushed = pushed, pulled = pulled, syncedAt = startedAt)
    }

    /** 例外を投げない版。UIから呼ぶときはこちらを使い、失敗しても操作をブロックしない */
    suspend fun trySync(userId: String): SyncState = try {
        val result = runSync(userId)
        SyncState(status = SyncStatus.IDLE, lastSyncedAt = result.syncedAt)
    } catch (e: Exception) {
        val message = e.message ?: "不明なエラー"

        // ネットワーク由来かどうかで表示を出し分ける
        val isOffline = Regex("network|socket|timeout|unresolved|connect", RegexOption.IGNORE_CASE)
            .containsMatchIn(message)

        SyncState(
            status = if (isOffline) SyncStatus.OFFLINE else SyncStatus.ERROR,
            lastSyncedAt = db.getMeta().lastSyncedAt,
            lastError = message,
        )
    }

    /** 設定画面に出す「未送信の変更」の件数 */
    fun getPendingCount(): Int {
        val since = db.getMeta().lastSyncedAt
        return tables.sumOf { pendingRows(it, since).size }
    }
}
