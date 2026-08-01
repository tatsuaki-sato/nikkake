# nikkake — Kotlin Multiplatform

React Native 版（リファレンス実装）に追従する実装です。
Android / iOS / Desktop の3プラットフォームで動きます。

全体設計は [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)、
機能仕様は [../docs/FEATURES.md](../docs/FEATURES.md) を参照。

## 技術スタック

| 用途 | 採用 |
|---|---|
| UI | Compose Multiplatform 1.5.11 |
| 言語 | Kotlin 1.9.21 |
| 状態管理 | Compose の `mutableStateOf` を持つ素のクラス |
| 画面遷移 | 自前の `Navigation`（sealed interface のスタック） |
| ローカル保存 | expect/actual（SharedPreferences / NSUserDefaults / java.util.prefs） |
| 日付 | kotlinx-datetime |
| シリアライズ | kotlinx-serialization |
| バックアップ | supabase-kt (gotrue-kt, postgrest-kt) |
| テスト | kotlin.test |

Voyager は依存から外しました。遷移が「4タブ＋上に重ねる数枚」だけで、
状態1つで足りる規模だからです。

## ディレクトリ

```
shared/src/
├── commonMain/kotlin/com/myapplication/common/
│   ├── App.kt                      エントリ。Supabase初期化に失敗してもnullで続行
│   ├── constants/Exercises.kt      プリセット種目、初期ルーティン
│   ├── data/
│   │   ├── Models.kt               全ドメインモデル
│   │   ├── PlatformStorage.kt      expect宣言＋テスト用のインメモリ実装
│   │   ├── LocalDb.kt              コレクションのCRUD、論理削除、差分抽出、UUID生成
│   │   ├── Repository.kt           画面が使うドメインAPI
│   │   └── SyncService.kt          Supabaseとの双方向同期
│   ├── domain/                     DateUtils.kt / Stats.kt（純粋関数）
│   ├── store/                      AppStore / WorkoutStore / AuthStore
│   └── ui/
│       ├── AppNavigator.kt         タブとスタックの制御
│       ├── components/Ui.kt        共通の部品
│       ├── screens/                各画面
│       └── theme/Theme.kt          配色と余白
├── androidMain/                    PlatformStorage.android.kt（SharedPreferences）
├── iosMain/                        PlatformStorage.ios.kt（NSUserDefaults）
├── desktopMain/                    PlatformStorage.desktop.kt（java.util.prefs）
└── commonTest/                     単体テスト
```

## ビルドに必要なもの

- **JDK 17**（必須）

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

- Androidターゲットをビルドするなら **Android SDK**。
  `local.properties` に `sdk.dir=/path/to/Android/sdk` を書くか、`ANDROID_HOME` を設定してください。
  `local.properties` は `.gitignore` 済みなので、クローン後に各自で作る必要があります。

## 起動と実行

```bash
./gradlew :desktopApp:run                    # デスクトップ（一番手軽）
./gradlew :androidApp:installDebug           # Android
```

iOS は `iosApp/` を Xcode で開いて実行します。

## テスト

```bash
./gradlew :shared:desktopTest                        # 77件
./gradlew :shared:compileKotlinIosSimulatorArm64     # iOSのコンパイル確認
./gradlew :shared:compileDebugKotlinAndroid          # Androidのコンパイル確認
```

Compose UI テストは未整備です（`compose.uiTest` が Compose 1.5.11 で解決できない）。
画面の検証は RN の Playwright と Flutter のシナリオテストでカバーしています。

## この実装に固有の事情

### タイムスタンプは文字列比較しない

`updated_at` は ISO8601 ですが、小数秒の有無で桁数が変わります。
`"…:00.500Z"` と `"…:00Z"` を辞書順で比べると `'.' < 'Z'` で**前後が逆転します**。
`LocalDb.isAfter()` で `Instant.parse` してから比較しています。

同期の取りこぼしに直結するので、`LocalDbTest` に専用のテストを置いています。

### SyncService は JsonObject を経由する

supabase-kt の `upsert` / `decodeList` は reified 型引数を要求するため、
`<T : SyncEntity<T>>` のままでは呼べません（`Cannot use 'T' as reified type parameter`）。

`JsonObject` に一度落としてから送受信することで、テーブル名とシリアライザのペアを
ループで回せるようにしています。テーブルが増えても書き足す場所は `tables` の1か所です。

### SyncEntity は自己型パラメータを取る

```kotlin
interface SyncEntity<T : SyncEntity<T>> {
    fun touched(updatedAt: String, deletedAt: String?): T
}
```

`LocalDb` が型を失わずに `updated_at` / `deleted_at` を書き換えるためです。
非ジェネリックにするとキャストが必要になります。

### PlatformStorage は expect class

`expect class` は共通のインターフェースを実装できないので、
`StorageAdapter` という薄い口で包み、実装（`PlatformStorage`）と
テスト用（`InMemoryStorage`）のどちらからでも `LocalDb` を作れるようにしています。

### Desktop の Preferences には8KB制限がある

`java.util.prefs` は1値あたり約8KBが上限なので、`PlatformStorage.desktop.kt` は
JSONを4000文字ずつのチャンクに割って保存し、読み出し時に連結します。

### Android では起動時に Context を渡す

```kotlin
NikkakeStorage.init(applicationContext)  // MainActivity.onCreate で
```

呼び忘れると `error()` で明示的に落とします。原因が分かりにくいクラッシュを避けるためです。

### 曜日の変換

`DayOfWeek.ordinal` は **月=0 … 日=6** ですが、DBは **日=0 … 土=6** です。
`(dayOfWeek.ordinal + 1) % 7` で変換しています。

### この回で直したビルド設定

ルートの `build.gradle.kts` に `plugins` ブロックが2つあり、
**プロジェクト全体が一切ビルドできない状態でした**。1つに統合してあります。

また `desktopApp` に `desktopMain` と `jvmMain` の重複した `main.kt` があったので、
実際に使われる `jvmMain` だけを残しました。
