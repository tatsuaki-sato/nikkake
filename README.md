# nikkake

毎日の日課（ルーティン）を記録して、習慣にするためのワークアウトアプリ。

**アプリを開いた瞬間から使えます。** サインインは不要で、ルーティンの作成も記録も統計もすべて動きます。
サインインは「機種変更やアプリの入れ直しで記録を失いたくない人」向けのバックアップ機能で、完全に任意です。

## 構成

ビジネスロジックは Rails に集約し、GraphQL で4つのクライアントへ供給します。

```
                 ┌──────────────────────────┐
                 │  nikkake_api (Rails 8)   │  ← ロジックはここにだけ置く
                 │  GraphQL / PostgreSQL    │
                 └────────────┬─────────────┘
                              │ GraphQL
      ┌──────────────┬────────┴───────┬──────────────┐
      │              │                │              │
  nikkake_web   nikkake_          nikkake_       nikkake_kmp
  (PC/SP Web)   react_native       flutter       (Compose MP)
```

| 実装 | ディレクトリ | 技術 | 位置づけ |
|---|---|---|---|
| Rails API | [nikkake_api](nikkake_api) | Ruby 4 / Rails 8 / graphql-ruby / PostgreSQL 16 | 仕様の実行可能な正典 |
| Web (PC/SP) | [nikkake_web](nikkake_web) | Vite 6, React 19, TanStack Query | サーバ主導のリファレンス |
| React Native | [nikkake_react_native](nikkake_react_native) | Expo 57, Expo Router, Zustand | サーバ／ローカル両モード |
| Flutter | [nikkake_flutter](nikkake_flutter) | Dart, Provider | サーバ／ローカル両モード |
| Kotlin Multiplatform | [nikkake_kmp](nikkake_kmp) | Compose Multiplatform | ローカルのみ（接続替え未了） |

**言語をまたぐ約束ごとは [packages/contract](packages/contract) が唯一の正**です。
プリセット種目・GraphQLスキーマ・ドメインの期待値をここに1本化し、
4言語のテストが同じファイルを読んで一致を検証しています（[docs/CONTRACT.md](docs/CONTRACT.md)）。

## ログイン不要と、サーバ主導の両立

サーバにロジックを寄せると、ふつうは「起動時にアカウントが要る」ことになります。
それを避けるために **遅延登録** という順序にしています。

```
初回起動
  1. 端末にプリセット種目と「いつものルーティン」を入れて、ホームを描く
     ← ここまでネットワークを一切使わない。圏外でも1タップで始められる
  2. 以降バックグラウンドで
       匿名アカウントを作る → 端末のデータをまるごと預ける
       成功したらサーバ計算モードへ切り替え。失敗したら次の起動で再試行
```

この順序は仕様です。逆にすると、アプリを入れた直後に圏外だと1歩も動きません。

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/FEATURES.md](docs/FEATURES.md) | 全画面・全機能の仕様（実装間の正典） |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | サーバ主導への移行、遅延登録、オフライン記録、タイムゾーン |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | テーブル定義、ID規約、論理削除、楽観ロック |
| [docs/CONTRACT.md](docs/CONTRACT.md) | 4言語の一致をどう機械的に守っているか |
| [docs/TESTING.md](docs/TESTING.md) | テストの構成と実行方法 |
| [docs/QA.md](docs/QA.md) | QAチェックリストと最新の実行結果、未検証の範囲 |
| [.agents/AGENTS.md](.agents/AGENTS.md) | エージェント向けの作業ルール |

## 動かす

### バックエンド

```bash
docker compose up -d db
```

```bash
cd nikkake_api && bin/rails db:prepare && bin/rails s
```

`docker compose up` で API ごと立てることもできます。Postgres は開発・CI・本番で
メジャーバージョンを揃えてください（16）。

### Web (PC/SP)

```bash
npm install && npm run web:dev
```

### React Native

```bash
cd nikkake_react_native && npm install && npm run web
```

サーバに繋ぐ場合:

```bash
cd nikkake_react_native && EXPO_PUBLIC_BACKEND=server npm run web
```

`EXPO_PUBLIC_BACKEND` を省くと `local`（端末のみ、ネットワーク不使用）で動きます。
移行中は両モードを維持し、同じ E2E スイートが両方で通ることを
挙動が変わっていないことの証明にしています。

### Flutter / Kotlin Multiplatform

```bash
cd nikkake_flutter && flutter pub get && flutter run
```

サーバに繋ぐ場合:

```bash
cd nikkake_flutter && flutter run --dart-define=BACKEND=server
```

```bash
cd nikkake_kmp && ./gradlew :desktopApp:run
```

KMP のビルドには JDK 17 が必要です。Android をビルドするなら
`local.properties` に `sdk.dir=...` を書くか `ANDROID_HOME` を設定してください。

## テストを全部走らせる

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
cd nikkake_flutter && flutter analyze && flutter test
```

```bash
cd nikkake_kmp && ./gradlew :shared:desktopTest
```

現在のテスト数と最新の実行結果は [docs/QA.md](docs/QA.md) を参照してください。

## データはどこにあるか

- **サーバ登録前**: 端末のローカルストレージのみ
- **登録後**: PostgreSQL が正。端末は読みキャッシュと、送信待ちの記録を持つ

記録（ワークアウト）は圏外でもキューに積まれ、復帰時に送られます。
ルーティンの作成・編集はオンラインが必要です。

詳細は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) を参照。
