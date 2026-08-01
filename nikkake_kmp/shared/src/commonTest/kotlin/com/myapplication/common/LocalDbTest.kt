package com.myapplication.common

import com.myapplication.common.data.Collections
import com.myapplication.common.data.LocalDb
import com.myapplication.common.data.Routine
import com.myapplication.common.data.Uuid
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LocalDbTest {

    private fun newRoutine(name: String, id: String = Uuid.v4()) = Routine(
        id = id,
        name = name,
        color = "#6C5CE7",
        icon = "💪",
        createdAt = "2026-01-01T00:00:00Z",
        updatedAt = "2026-01-01T00:00:00Z",
    )

    private val serializer = Routine.serializer()

    @Test
    fun uuidはRFC4122v4の形式になる() {
        val id = Uuid.v4(Random(42))
        val pattern = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
        assertTrue(pattern.matches(id), "unexpected uuid: $id")
    }

    @Test
    fun insertはタイムスタンプを打ち直す() {
        val db = createTestDb()
        val row = db.insert(Collections.ROUTINES, serializer, newRoutine("朝トレ"))

        assertNull(row.deletedAt)
        // 渡した値ではなく、保存時刻で上書きされる
        assertTrue(row.updatedAt > "2026-01-01T00:00:00Z")
    }

    @Test
    fun 明示的なIDは尊重される() {
        val db = createTestDb()
        val row = db.insert(Collections.ROUTINES, serializer, newRoutine("固定", id = "fixed-id"))
        assertEquals("fixed-id", row.id)
    }

    @Test
    fun findとlistで絞り込める() {
        val db = createTestDb()
        db.insertMany(Collections.ROUTINES, serializer, listOf(newRoutine("A"), newRoutine("B")))

        val all = db.list(Collections.ROUTINES, serializer)
        assertEquals(2, all.size)
        assertNotNull(db.find(Collections.ROUTINES, serializer, all.first().id))
    }

    @Test
    fun updateはupdatedAtを進める() {
        val db = createTestDb()
        val row = db.insert(Collections.ROUTINES, serializer, newRoutine("元の名前"))

        val updated = db.update(Collections.ROUTINES, serializer, row.id) { it.copy(name = "新しい名前") }

        assertEquals("新しい名前", updated?.name)
        assertTrue(updated!!.updatedAt >= row.updatedAt)
    }

    @Test
    fun 存在しないIDのupdateはnull() {
        val db = createTestDb()
        assertNull(db.update(Collections.ROUTINES, serializer, "missing") { it })
    }

    @Test
    fun 論理削除した行はlistから消えるが生データには残る() {
        val db = createTestDb()
        val row = db.insert(Collections.ROUTINES, serializer, newRoutine("消す"))

        assertTrue(db.softDelete(Collections.ROUTINES, serializer, row.id))
        assertTrue(db.list(Collections.ROUTINES, serializer).isEmpty())

        // 削除された事実が同期先に伝わる必要があるので、行自体は残す
        val raw = db.readRaw(Collections.ROUTINES, serializer)
        assertEquals(1, raw.size)
        assertNotNull(raw.first().deletedAt)
    }

    @Test
    fun softDeleteWhereは条件に合う行だけ消す() {
        val db = createTestDb()
        db.insertMany(
            Collections.ROUTINES,
            serializer,
            listOf(newRoutine("残す"), newRoutine("消す"), newRoutine("消す")),
        )

        assertEquals(2, db.softDeleteWhere(Collections.ROUTINES, serializer) { it.name == "消す" })
        assertEquals(1, db.list(Collections.ROUTINES, serializer).size)
    }

    @Test
    fun 削除済みを再削除しても二重に数えない() {
        val db = createTestDb()
        db.insert(Collections.ROUTINES, serializer, newRoutine("消す"))
        db.softDeleteWhere(Collections.ROUTINES, serializer) { true }

        assertEquals(0, db.softDeleteWhere(Collections.ROUTINES, serializer) { true })
    }

    @Test
    fun upsertFromRemoteは新しい方を採用する() {
        val db = createTestDb()
        val local = db.insert(Collections.ROUTINES, serializer, newRoutine("ローカル版"))

        db.upsertFromRemote(
            Collections.ROUTINES,
            serializer,
            listOf(local.copy(name = "古いリモート版", updatedAt = "2020-01-01T00:00:00Z")),
        )
        assertEquals("ローカル版", db.find(Collections.ROUTINES, serializer, local.id)?.name)

        db.upsertFromRemote(
            Collections.ROUTINES,
            serializer,
            listOf(local.copy(name = "新しいリモート版", updatedAt = "2099-01-01T00:00:00Z")),
        )
        assertEquals("新しいリモート版", db.find(Collections.ROUTINES, serializer, local.id)?.name)
    }

    @Test
    fun 小数秒の有無で前後関係が逆転しない() {
        // 文字列比較だと "…:00.500Z" < "…:00Z" になってしまう（'.' < 'Z'）。
        // 同期の取りこぼしに直結するので明示的に守る。
        val db = createTestDb()
        val local = db.insert(
            Collections.ROUTINES,
            serializer,
            newRoutine("ローカル版").copy(updatedAt = "2026-08-01T00:00:00.500Z"),
        )

        db.upsertFromRemote(
            Collections.ROUTINES,
            serializer,
            listOf(local.copy(name = "1秒前のリモート版", updatedAt = "2026-08-01T00:00:00Z")),
        )

        assertEquals(
            "ローカル版",
            db.find(Collections.ROUTINES, serializer, local.id)?.name,
            "小数秒付きのローカル値の方が新しいので上書きされてはいけない",
        )
    }

    @Test
    fun upsertFromRemoteは未知のIDを挿入する() {
        val db = createTestDb()
        val result = db.upsertFromRemote(
            Collections.ROUTINES,
            serializer,
            listOf(newRoutine("リモート発", id = "remote-1")),
        )

        assertEquals(1, result.inserted)
        assertEquals(0, result.updated)
        assertEquals(1, db.list(Collections.ROUTINES, serializer).size)
    }

    @Test
    fun changedSinceはカーソル以降だけ返す() {
        val db = createTestDb()
        db.insert(Collections.ROUTINES, serializer, newRoutine("古い"))
        val cursor = db.readRaw(Collections.ROUTINES, serializer).first().updatedAt

        db.insert(
            Collections.ROUTINES,
            serializer,
            newRoutine("新しい").copy(updatedAt = "2099-01-01T00:00:00Z"),
        )

        val changed = db.changedSince(Collections.ROUTINES, serializer, cursor)
        assertEquals(1, changed.size)
        assertEquals("新しい", changed.first().name)
    }

    @Test
    fun カーソルがnullなら全件が対象() {
        val db = createTestDb()
        db.insertMany(Collections.ROUTINES, serializer, listOf(newRoutine("A"), newRoutine("B")))
        assertEquals(2, db.changedSince(Collections.ROUTINES, serializer, null).size)
    }

    @Test
    fun メタ情報は初期値を返し部分更新できる() {
        val db = createTestDb()
        val meta = db.getMeta()
        assertFalse(meta.seeded)
        assertNull(meta.lastSyncedAt)

        db.setMeta(seeded = true)
        val updated = db.getMeta()

        assertTrue(updated.seeded)
        assertEquals(LocalDb.CURRENT_SCHEMA_VERSION, updated.schemaVersion)
    }

    @Test
    fun resetで全部消える() {
        val db = createTestDb()
        db.insert(Collections.ROUTINES, serializer, newRoutine("消える"))
        db.setMeta(seeded = true)

        db.reset()

        assertTrue(db.list(Collections.ROUTINES, serializer).isEmpty())
        assertFalse(db.getMeta().seeded)
    }
}
