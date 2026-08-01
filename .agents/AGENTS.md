# nikkake — エージェント向け作業ルール

このリポジトリには同じアプリの実装が3つ入っています。

| 実装 | ディレクトリ | 技術 |
|---|---|---|
| React Native / Expo | `nikkake_react_native/` | TypeScript, Expo Router, Zustand, TanStack Query, Playwright |
| Flutter | `nikkake_flutter/` | Dart, Provider, shared_preferences |
| Kotlin Multiplatform | `nikkake_kmp/` | Compose Multiplatform, kotlinx-serialization |

パスはこのファイルからの相対で、リポジトリのルートは `nikkake/` です。

## 変更前に必ず読むもの

1. [../docs/FEATURES.md](../docs/FEATURES.md) — 仕様の正典。挙動に迷ったらここが正
2. [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — ローカルファースト設計と同期の仕組み
3. 触る実装の `DEVELOPMENT_CONTEXT.md`

## 絶対に壊してはいけないもの

**サインインなしで全機能が使えること。** これがこのアプリの根幹です。

- 起動導線にログイン画面を挟まない
- データの読み書きにネットワークを介在させない
- Supabase の初期化に失敗しても、ローカルモードで通常どおり起動する

`nikkake_react_native/e2e/startup.spec.ts` がこれを守っています。

## 仕様を変えるときの手順

1. **React Native 版を先に変更する**（リファレンス実装）
2. `docs/FEATURES.md` を更新する
3. Flutter と KMP を追従させる
4. 3実装すべてのテストを更新する（対応表は [../docs/TESTING.md](../docs/TESTING.md)）
5. 3実装すべてのテストを実行して通す

**1つの実装だけ変えて終わりにしない。** パリティが崩れると、次に触る人が
どれが正しいのか判断できなくなります。

## 3か所同時に直す必要があるもの

| 対象 | ファイル |
|---|---|
| プリセット種目のID | `nikkake_react_native/src/constants/exercises.ts`<br>`nikkake_flutter/lib/constants/exercises.dart`<br>`nikkake_kmp/shared/src/commonMain/kotlin/com/myapplication/common/constants/Exercises.kt`<br>＋ `nikkake_react_native/supabase/migrations/20260801000000_local_first_sync.sql` |
| 配色・余白 | `src/constants/colors.ts` / `lib/constants/colors.dart` / `ui/theme/Theme.kt` |
| バリデーションの文言 | 各実装のフォーム画面 |

## データを扱うときの注意

- **削除は論理削除**（`deleted_at` を立てる）。物理削除にすると同期で復活する
- **`updated_at` の比較は必ず時刻としてパースしてから**。文字列比較は小数秒で前後が逆転する
- **IDはクライアントで生成する**。サーバ採番にするとオフラインで作れなくなる

## テストの実行

```bash
cd nikkake_react_native && npm run verify
```

```bash
cd nikkake_flutter && flutter analyze && flutter test
```

```bash
cd nikkake_kmp && ./gradlew :shared:desktopTest
```

KMPは JDK 17 が必要です（`JAVA_HOME` を設定）。

## リリース前

[../docs/QA.md](../docs/QA.md) のチェックリストを使ってください。
自動テストで担保できていない範囲（実機、Supabaseとの実通信）が明記されています。
