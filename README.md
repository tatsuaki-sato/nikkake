# nikkake

毎日の日課（ルーティン）を記録して、習慣にするためのワークアウトアプリ。

**アプリを開いた瞬間から使えます。** サインインは不要で、ルーティンの作成も記録も統計もすべて動きます。
サインインは「機種変更やアプリの入れ直しで記録を失いたくない人」向けのバックアップ機能で、完全に任意です。

このリポジトリには同じアプリの実装が3つ入っています。仕様・データモデル・画面構成・配色はすべて揃えてあります。

| 実装 | ディレクトリ | 技術 | 位置づけ |
|---|---|---|---|
| React Native / Expo | [nikkake_react_native](nikkake_react_native) | TypeScript, Expo Router, Zustand, TanStack Query | リファレンス実装 |
| Flutter | [nikkake_flutter](nikkake_flutter) | Dart, Provider, shared_preferences | パリティ達成 |
| Kotlin Multiplatform | [nikkake_kmp](nikkake_kmp) | Compose Multiplatform, kotlinx-serialization | パリティ達成 |

仕様変更を入れるときは **React Native 版を先に変更し、他2つを追従させる** のが原則です。

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | ローカルファースト設計、同期の仕組み、3実装の層構成 |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | テーブル定義、ID規約、論理削除、RLS |
| [docs/FEATURES.md](docs/FEATURES.md) | 全画面・全機能の仕様（実装間の正典） |
| [docs/TESTING.md](docs/TESTING.md) | テストの構成と実行方法 |
| [docs/QA.md](docs/QA.md) | リリース前のQAチェックリストと最新の実行結果 |
| [.agents/AGENTS.md](.agents/AGENTS.md) | エージェント向けの作業ルール |

各実装の固有事情は `nikkake_*/DEVELOPMENT_CONTEXT.md` にあります。

## クイックスタート

### React Native (Expo)

```bash
cd nikkake_react_native && npm install && npm run web
```

### Flutter

```bash
cd nikkake_flutter && flutter pub get && flutter run
```

### Kotlin Multiplatform（デスクトップで確認するのが一番速い）

```bash
cd nikkake_kmp && ./gradlew :desktopApp:run
```

KMPのビルドには JDK 17 が必要です。Androidターゲットをビルドする場合は `local.properties` に
`sdk.dir=/path/to/Android/sdk` を書くか、`ANDROID_HOME` を設定してください。

## テストを全部走らせる

```bash
cd nikkake_react_native && npm run verify
```

```bash
cd nikkake_flutter && flutter analyze && flutter test
```

```bash
cd nikkake_kmp && ./gradlew :shared:desktopTest
```

現在のテスト数と最新の実行結果は [docs/QA.md](docs/QA.md) を参照してください。

## データはどこにあるか

- **既定**: 端末のローカルストレージのみ（RN: AsyncStorage / Flutter: SharedPreferences / KMP: SharedPreferences・NSUserDefaults・java.util.prefs）
- **サインイン時**: 上記に加えて Supabase へ複製。ローカルが常に正で、クラウドはバックアップ先

詳細は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) を参照。
