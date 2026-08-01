package com.myapplication.common.data

/**
 * 端末ごとのキー・バリュー保存。
 *
 * Android は SharedPreferences、iOS は NSUserDefaults、Desktop は java.util.prefs を使う。
 * 外部ライブラリを足さずに expect/actual で済ませているのは、
 * 保存するものが「JSON文字列を数本」だけで、ライブラリを挟む利点が無いため。
 */
expect class PlatformStorage {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun remove(key: String)
    fun keys(): Set<String>
}

/**
 * テストと、保存先を差し替えたい場合のためのインメモリ実装。
 * commonTest からはこれを使うので、テストが端末の状態に依存しない。
 */
class InMemoryStorage {
    private val map = mutableMapOf<String, String>()

    fun getString(key: String): String? = map[key]
    fun putString(key: String, value: String) {
        map[key] = value
    }

    fun remove(key: String) {
        map.remove(key)
    }

    fun keys(): Set<String> = map.keys.toSet()
}

/**
 * PlatformStorage と InMemoryStorage のどちらでも LocalStore を作れるようにする薄い口。
 * expect class は共通のインターフェースを実装できないため、関数で包んでいる。
 */
class StorageAdapter(
    private val getter: (String) -> String?,
    private val putter: (String, String) -> Unit,
    private val remover: (String) -> Unit,
    private val keysProvider: () -> Set<String>,
) {
    fun getString(key: String): String? = getter(key)
    fun putString(key: String, value: String) = putter(key, value)
    fun remove(key: String) = remover(key)
    fun keys(): Set<String> = keysProvider()

    companion object {
        fun of(storage: PlatformStorage) = StorageAdapter(
            getter = storage::getString,
            putter = storage::putString,
            remover = storage::remove,
            keysProvider = storage::keys,
        )

        fun of(storage: InMemoryStorage) = StorageAdapter(
            getter = storage::getString,
            putter = storage::putString,
            remover = storage::remove,
            keysProvider = storage::keys,
        )

        fun inMemory() = of(InMemoryStorage())
    }
}
