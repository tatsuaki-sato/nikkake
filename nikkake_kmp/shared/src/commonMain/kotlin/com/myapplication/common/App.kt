package com.myapplication.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import com.myapplication.common.data.Backend
import com.myapplication.common.data.BackendSwitch
import com.myapplication.common.data.LocalDb
import com.myapplication.common.data.PlatformStorage
import com.myapplication.common.data.StorageAdapter
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.AuthStore
import com.myapplication.common.store.WorkoutStore
import com.myapplication.common.ui.AppNavigator
import com.myapplication.common.ui.theme.NikkakeTheme
import kotlinx.coroutines.launch

/**
 * データ取得元の既定値。
 *
 * サーバに繋ぐ場合はビルド設定（`-Pnikkake.backend=server` 相当）で上書きする。
 * 未指定ならローカル実装のみで動く。
 */
expect val defaultBackend: Backend
expect val defaultApiEndpoint: String

/**
 * アプリのエントリポイント。
 *
 * サーバへの登録に失敗しても、ローカルモードでアプリは完全に動く。
 * ここで例外を投げて起動を止めるのは「ログイン不要で使える」という要件に反するので、
 * 登録は結果を待たずバックグラウンドで行う（遅延登録）。
 */
@Composable
fun App(db: LocalDb? = null, backend: Backend = defaultBackend) {
    val localDb = remember(db) { db ?: LocalDb(StorageAdapter.of(PlatformStorage())) }
    val backendSwitch = remember(localDb, backend) {
        BackendSwitch(db = localDb, backend = backend, endpoint = defaultApiEndpoint)
    }
    val appStore = remember(backendSwitch) { AppStore(backendSwitch) }
    val workoutStore = remember(backendSwitch) { WorkoutStore(backendSwitch) }
    val authStore = remember(backendSwitch) { AuthStore(backendSwitch) }

    val scope = rememberCoroutineScope()

    LaunchedEffect(backendSwitch) {
        // 初回起動時にプリセット種目と「いつものルーティン」を端末に用意する。
        // ここが終わればサインインの有無に関係なくアプリは完全に使える。
        backendSwitch.prepareLocalData()
        appStore.bootstrap()

        // 以降はUIをブロックしない。
        // サーバへの登録も認証確認も、表示には必要ない。
        scope.launch {
            val registered = backendSwitch.registerInBackground()
            if (registered) {
                // 登録が終わるとデータ元がローカルからサーバへ切り替わる。
                // 表示中の内容はローカル由来なので読み直す
                appStore.refresh()
            }
            authStore.initialize()
        }
    }

    NikkakeTheme(darkTheme = true) {
        AppNavigator(appStore = appStore, workoutStore = workoutStore, authStore = authStore)
    }
}
