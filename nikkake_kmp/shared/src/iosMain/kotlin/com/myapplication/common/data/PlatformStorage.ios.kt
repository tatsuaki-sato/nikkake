package com.myapplication.common.data

import platform.Foundation.NSUserDefaults

/**
 * iOS では NSUserDefaults に保存する。
 * アプリ削除でのみ消える永続領域で、この用途（数本のJSON文字列）には十分。
 */
actual class PlatformStorage {
    private val defaults = NSUserDefaults.standardUserDefaults

    actual fun getString(key: String): String? = defaults.stringForKey(key)

    actual fun putString(key: String, value: String) {
        defaults.setObject(value, key)
    }

    actual fun remove(key: String) {
        defaults.removeObjectForKey(key)
    }

    actual fun keys(): Set<String> =
        defaults.dictionaryRepresentation().keys.mapNotNull { it as? String }.toSet()
}
