package com.myapplication.common.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.myapplication.common.data.StorageMode
import com.myapplication.common.data.SyncService
import com.myapplication.common.data.SyncState
import com.myapplication.common.data.SyncStatus
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.user.UserInfo

/**
 * 認証は「任意」。
 *
 * このアプリはサインインしなくても全機能が使える。
 * サインインの意味は「端末を変えてもデータが残る」ことだけなので、
 * このストアが未サインインでも画面は一切ブロックしない。
 */
class AuthStore(
    private val syncService: SyncService,
    private val auth: Auth,
) {
    var user by mutableStateOf<UserInfo?>(null)
        private set
    var sync by mutableStateOf(SyncState())
        private set
    var initialized by mutableStateOf(false)
        private set

    val mode: StorageMode get() = if (user == null) StorageMode.LOCAL else StorageMode.CLOUD

    suspend fun initialize() {
        sync = SyncState(lastSyncedAt = syncService.db.getMeta().lastSyncedAt)
        user = runCatching { auth.currentUserOrNull() }.getOrNull()
        initialized = true

        if (user != null) syncNow()
    }

    /** 成功時は null、失敗時はユーザー向けのメッセージを返す */
    suspend fun signIn(email: String, password: String): String? = try {
        auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        user = auth.currentUserOrNull()
        syncNow()
        null
    } catch (e: Exception) {
        val message = e.message ?: "サインインに失敗しました"
        if (message.contains("Invalid login credentials")) "メールアドレスまたはパスワードが違います" else message
    }

    suspend fun signUp(email: String, password: String): String? = try {
        auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        // メール確認が必要な設定の場合、この時点ではセッションが無い
        user = auth.currentUserOrNull()
        if (user != null) syncNow()
        null
    } catch (e: Exception) {
        e.message ?: "アカウント作成に失敗しました"
    }

    /**
     * サインアウトしてもローカルのデータは消さない。
     * 「バックアップをやめる」だけであって、記録を捨てる操作ではないため。
     */
    suspend fun signOut() {
        runCatching { auth.signOut() }
        user = null
    }

    suspend fun syncNow() {
        val current = user ?: return

        sync = sync.copy(status = SyncStatus.SYNCING, lastError = null)

        // サインイン前に作ったローカルのレコードをこのアカウントのものにする
        syncService.claimLocalRows(current.id)
        sync = syncService.trySync(current.id)
    }

    val pendingCount: Int get() = syncService.getPendingCount()
}
