package com.myapplication.common.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Android では SharedPreferences に保存する。
 *
 * Context が要るので、Application 起動時に [NikkakeStorage.init] を呼んでおく。
 * 呼び忘れた場合は例外ではっきり落として、原因を分かりやすくする。
 */
actual class PlatformStorage {
    private val prefs: SharedPreferences get() = NikkakeStorage.requirePrefs()

    actual fun getString(key: String): String? = prefs.getString(key, null)

    actual fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    actual fun remove(key: String) {
        prefs.edit().remove(key).apply()
    }

    actual fun keys(): Set<String> = prefs.all.keys.toSet()
}

object NikkakeStorage {
    private const val PREFS_NAME = "nikkake"
    private var prefs: SharedPreferences? = null

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    internal fun requirePrefs(): SharedPreferences = prefs
        ?: error("NikkakeStorage.init(context) を Application#onCreate で呼んでください")
}
