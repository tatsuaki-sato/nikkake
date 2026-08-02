# テスト

## 方針

- **ロジックは Rails の純粋関数に寄せて RSpec で守る**（日付判定・統計・文言）
- **言語をまたぐ一致は共通のフィクスチャで守る**（[CONTRACT.md](CONTRACT.md)）
- **画面はアプリ全体を起動するシナリオテストで守る**（部品単位のスナップショットは撮らない）
- **E2Eは認証をモックしない**。サインイン不要の設計なので、そもそも準備が要らない

## 全体像

```
packages/contract/domain_cases.json   ← 期待値はここ1本
  ├── nikkake_api          RSpec
  ├── nikkake_react_native Jest
  ├── nikkake_flutter      flutter test
  └── nikkake_kmp          Gradle (desktopTest)
```

| 実装 | 単体 | E2E | 合計 |
|---|---:|---:|---:|
| Rails API | 137 (RSpec) | — | 137 |
| Web | — | 26 (Playwright ×2) | 26 |
| React Native | 181 (Jest) | 84 (Playwright ×2) ×2モード | 265 |
| Flutter | 192 (flutter test) | — | 192 |
| KMP | 83 (kotlin.test) | — | 83 |

最新の実行結果は [QA.md](QA.md) を参照。

## 実行

```bash
npm run verify:contract
```

```bash
cd nikkake_api && bundle exec rspec
```

```bash
cd nikkake_react_native && npm run verify
```

```bash
cd nikkake_web && npx playwright test
```

```bash
cd nikkake_flutter && flutter analyze && flutter test
```

```bash
cd nikkake_kmp && ./gradlew :shared:desktopTest
```

KMP は JDK 17 が必要です（`JAVA_HOME` を設定）。

### サーバが要るもの

Web の E2E と、React Native のサーバモード E2E は Rails と PostgreSQL が要ります。

```bash
docker compose up -d db
```

```bash
cd nikkake_api && CORS_ORIGINS=http://localhost:8081,http://localhost:5173 bin/rails s
```

```bash
cd nikkake_react_native && EXPO_PUBLIC_BACKEND=server npx playwright test
```

**CORS を渡さないと、Expo Web からの呼び出しがブラウザにブロックされます。**
そのとき遅延登録は設計どおり黙って失敗し、アプリはローカルモードのまま完動します。
つまり **E2E は通ってしまい、サーバ経路を1行も検証していない状態になります。**
実際にこれを踏みました。サーバモードを確かめたときは、DBの中身も見てください。

```bash
psql -d nikkake_api_development -c "select count(*) from routine_logs;"
```

## 何をどこで守っているか

### Rails（137 examples）

| 対象 | ファイル |
|---|---|
| ドメイン関数の契約 | `spec/domain/contract_spec.rb` |
| ビュー組み立て | `spec/services/` |
| GraphQL の入出力 | `spec/requests/graphql_spec.rb` |
| 設計の不変条件 | `spec/architecture_spec.rb` |

`architecture_spec.rb` が守っているのは3つです。**回避しないでください。**

1. サーバが「今日」を計算していないこと（`Date.today` などを禁止）
2. リゾルバがモデルクラスから直接 `find` していないこと（認可の主防御）
3. すべてのミューテーションの戻り値に `userErrors` があること

コメントと文字列リテラルを除去してから検査しています。
これをしないと、禁止理由を説明したコメント自体が引っかかります。

### React Native（Jest 181 / Playwright 84 ×2モード）

| 対象 | ファイル |
|---|---|
| ドメイン関数の契約 | `src/lib/__tests__/contract.test.ts` |
| ローカルDB | `src/lib/__tests__/localDb.test.ts` |
| データAPI | `src/lib/__tests__/repository.test.ts` |
| 集計済みビュー | `src/lib/__tests__/views.test.ts` |
| 実行中の状態 | `src/stores/__tests__/workoutStore.test.ts` |
| 画面 | `e2e/*.spec.ts` |

`views.test.ts` はローカル実装が**サーバと同じ形・同じ区分**を返すことを確かめます。
片方だけ変えると、ローカルモードとサーバモードで画面の中身が食い違います。

E2E は同じスイートを `local` と `server` の両モードで走らせます。
**両方通ることが、移行で挙動が変わっていないことの証明**です。

### Web（Playwright 26）

`e2e/startup.spec.ts` と `e2e/workout.spec.ts`。
オフライン記録（`context.setOffline(true)` で記録 → キュー滞留 → 復帰 → 送信）を含みます。

### Flutter（192）/ KMP（83）

契約テストと、画面のシナリオテスト。
Flutter にはサーバ実装のテストが13件あり、応答を差し替えて検証しています。

**`flutter test` は HTTP を差し替えるため、実サーバとの疎通は確認できません。**
`TestWidgetsFlutterBinding` が全リクエストに 400 を返します。
Flutter のサーバ接続を確かめるには実機か実サーバで動かしてください。

Flutter のウィジェットテストは既定の 800×600 だと画面外のウィジェットが構築されないので、
`tester.view.physicalSize` を広げています。

Kotlin の契約テストは `commonTest` ではなく `desktopTest` にあります
（common からはファイルを読めないため）。
契約ディレクトリの絶対パスは `build.gradle.kts` からシステムプロパティで渡します。
Gradle の作業ディレクトリはモジュール直下なので、相対パス頼みだと壊れます。

## 検査そのものを一度壊すこと

「壊したら落ちる」ことを確認していない検査は、通っていても意味がありません。
このリポジトリの検査は一度ずつ意図的に壊して確認済みです（[CONTRACT.md](CONTRACT.md)）。
新しく足すときも同じようにしてください。

## E2E を書くときの注意（React Native / Web）

- expo-router の Web 実装ではタブが `<a role="tab">` になります
- **前の画面がマウントされたまま残ります。** `testID` はスクリーン単位で絞らないと
  strict-mode 違反になります
- サマリーから `router.replace('/(tabs)')` すると、既にあるタブ画面の上に
  もう1つ積まれます。`canGoBack()` を見て `back()` してください
- 固定UUIDでウィジェットを引かないこと。初期ルーティンのIDは端末ごとに変わります
