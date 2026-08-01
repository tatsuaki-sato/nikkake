package com.myapplication.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.myapplication.common.data.LocalDb
import com.myapplication.common.data.PlatformStorage
import com.myapplication.common.data.Repository
import com.myapplication.common.data.StorageAdapter
import com.myapplication.common.data.SyncService
import com.myapplication.common.store.AppStore
import com.myapplication.common.store.AuthStore
import com.myapplication.common.store.WorkoutStore
import com.myapplication.common.ui.AppNavigator
import com.myapplication.common.ui.theme.NikkakeTheme
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.Postgrest

/**
 * Supabaseはバックアップ先としてのみ使う。
 * anonキーはクライアントに埋め込む前提の公開値で、行単位のアクセス制御はRLSが担う。
 */
private const val SUPABASE_URL = "https://igptzltkydyghneioedm.supabase.co"
private const val SUPABASE_ANON_KEY =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlncHR6bHRreWR5Z2huZWlvZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDMyNjEsImV4cCI6MjA5OTI3OTI2MX0.pNprCQcr4GkAY86VhF9JUHYtpGxavQxDJjpodea1dAE"

/**
 * アプリのエントリポイント。
 *
 * Supabaseの初期化に失敗しても、ローカルモードでアプリは完全に動く。
 * ここで例外を投げて起動を止めるのは「ログイン不要で使える」という要件に反するので、
 * authStore は null 許容にしてある。
 */
@Composable
fun App(db: LocalDb? = null, enableCloudBackup: Boolean = true) {
    val localDb = remember(db) { db ?: LocalDb(StorageAdapter.of(PlatformStorage())) }
    val repository = remember(localDb) { Repository(localDb) }
    val appStore = remember(repository) { AppStore(repository) }
    val workoutStore = remember(repository) { WorkoutStore(repository) }

    val authStore = remember(localDb, enableCloudBackup) {
        if (!enableCloudBackup) return@remember null

        runCatching {
            val client = createSupabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY) {
                install(Auth)
                install(Postgrest)
            }
            AuthStore(SyncService(localDb, client), client.auth)
        }.getOrNull()
    }

    NikkakeTheme(darkTheme = true) {
        AppNavigator(appStore = appStore, workoutStore = workoutStore, authStore = authStore)
    }
}
