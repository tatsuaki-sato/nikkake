package com.myapplication.common.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.myapplication.common.data.BackendSwitch
import com.myapplication.common.data.StorageMode
import com.myapplication.common.data.Viewer

/**
 * アカウントの状態。
 *
 * サインインは「任意」で、意味は**端末を変えてもデータが残ること**だけです。
 * サインインしていなくても全機能が使えるので、このストアが画面をブロックすることはありません。
 *
 * 匿名でも記録はサーバに預けられています。違いは取り戻す手段だけで、
 * 匿名だとこの端末のトークンを失った時点で辿り着けなくなります。
 *
 * **メール登録でデータは1件も移動しません。** 匿名アカウントに
 * メールとパスワードを足すだけで user.id が変わらないためです。
 * 移行前にあった claimLocalRows のような引き取り処理は不要になりました。
 */
class AuthStore(private val backend: BackendSwitch) {

    var viewer by mutableStateOf<Viewer?>(null)
        private set
    var pendingCount by mutableStateOf(0)
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    var initialized by mutableStateOf(false)
        private set

    val mode: StorageMode
        get() = if (viewer == null || viewer?.isAnonymous == true) StorageMode.LOCAL else StorageMode.CLOUD

    suspend fun initialize() {
        refresh()
        initialized = true
    }

    suspend fun refresh() {
        pendingCount = backend.pendingCount()

        val api = backend.server
        // サーバに登録できていないあいだは、そもそも聞きに行く相手がいない
        if (api == null || !backend.isServerReady) {
            viewer = null
            return
        }

        viewer = try {
            api.viewer()
        } catch (e: Exception) {
            // 圏外でも画面は出す。次に開いたときに取り直す
            null
        }
    }

    /**
     * 既にあるアカウントへ切り替える。
     * この端末の匿名データを取り込むかは merge で決める（既定は取り込まない）。
     */
    suspend fun signIn(email: String, password: String): String? {
        val api = backend.server ?: return "この端末はサーバに接続していません"

        return try {
            viewer = api.linkExistingAccount(email = email, password = password)
            null
        } catch (e: com.myapplication.common.data.PermanentFailure) {
            // サーバは userErrors.message にそのまま画面へ出せる日本語を入れて返す
            e.message ?: "サインインに失敗しました"
        } catch (e: Exception) {
            "サーバに接続できませんでした。電波の良いところで試してください。"
        }
    }

    /**
     * いま使っている匿名アカウントにメールとパスワードを足す。
     * 新しいアカウントを作るのではないので、記録はそのまま残る。
     */
    suspend fun signUp(email: String, password: String, displayName: String? = null): String? {
        val api = backend.server ?: return "この端末はサーバに接続していません"

        return try {
            viewer = api.attachEmailPassword(email = email, password = password, displayName = displayName)
            null
        } catch (e: com.myapplication.common.data.PermanentFailure) {
            e.message ?: "アカウント作成に失敗しました"
        } catch (e: Exception) {
            "サーバに接続できませんでした。電波の良いところで試してください。"
        }
    }

    /**
     * サインアウトしても記録は消えません。
     * この端末から見えなくなるだけで、同じアカウントで入り直せば戻ります。
     */
    suspend fun signOut() {
        val api = backend.server
        try {
            api?.signOut()
        } finally {
            viewer = null
        }
    }

    /** 送信待ちの記録を送る */
    suspend fun flushNow() {
        val api = backend.server ?: return

        try {
            api.flushQueue()
            lastError = null
        } catch (e: Exception) {
            lastError = e.message
        }
        pendingCount = backend.pendingCount()
    }
}
