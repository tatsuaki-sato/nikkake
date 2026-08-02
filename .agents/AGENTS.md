# nikkake — エージェント向け作業ルール

Rails のバックエンド1つと、クライアント4つが入っています。

| 実装 | ディレクトリ | 技術 |
|---|---|---|
| Rails API | `nikkake_api/` | Ruby 4, Rails 8, graphql-ruby, PostgreSQL 16, RSpec |
| Web (PC/SP) | `nikkake_web/` | Vite, React 19, TanStack Query, Playwright |
| React Native | `nikkake_react_native/` | Expo 57, Expo Router, Zustand, Jest, Playwright |
| Flutter | `nikkake_flutter/` | Dart, Provider |
| Kotlin Multiplatform | `nikkake_kmp/` | Compose Multiplatform, kotlinx-serialization |

パスはこのファイルからの相対で、リポジトリのルートは `nikkake/` です。

## 変更前に必ず読むもの

1. [../docs/FEATURES.md](../docs/FEATURES.md) — 仕様の正典。挙動に迷ったらここが正
2. [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — サーバ主導、遅延登録、タイムゾーン
3. [../docs/CONTRACT.md](../docs/CONTRACT.md) — 4言語の一致をどう守っているか

## 絶対に壊してはいけないもの

### 1. サインインなしで全機能が使えること

これがこのアプリの根幹です。

- 起動導線にログイン画面を挟まない
- **サーバへの登録を待ってから画面を出さない。** 端末にシードして描画するのが先
- サーバが落ちていても、記録は積めて後から送られる

`nikkake_react_native/e2e/startup.spec.ts` と `nikkake_web/e2e/startup.spec.ts` が守っています。

### 2. サーバが「今日」を計算しないこと

日付はクライアントが決めてサーバへ送ります。サーバで `Date.today` を使うと、
日本の朝8時が UTC では前日23時なので、その瞬間にストリークが1日ずれます。

`nikkake_api/spec/architecture_spec.rb` が機械的に検査しています。回避しないでください。

### 3. ロジックをクライアントへ戻さないこと

区分（今日やる／予定なし／完了）、集計、頻度の文言はすべてサーバが決めます。
画面に計算が生えたら、それはサーバへ移すべきものが漏れている合図です。

クライアントに残してよいのは以下だけで、理由も決まっています。

| 残すもの | 理由 |
|---|---|
| 日付文字列の生成 | `log_date` を端末が決めるため（上記2） |
| `formatDuration` / `formatWeight` | 毎秒描画・入力中表示で往復できない |
| ローカル実装一式（RN） | 登録が終わるまでの遅延登録モード用 |

## 仕様を変えるときの手順

1. **`packages/contract/` を直す**（スキーマ、プリセット、期待値）
2. `nikkake_api/` を直して `bundle exec rspec` を通す
3. `bundle exec rake graphql:verify` でスキーマと実装の差を潰す
4. クライアントを追従させる
5. [../docs/FEATURES.md](../docs/FEATURES.md) を更新する

**表示する文言をクライアントに書き足さない。** 「毎日」「3日ごと」「前回: 50×10」などは
サーバが文字列で返します。4実装に散らすと必ずどれかが古くなります。

## 契約を直せば全部に効くもの

以前は「4か所同時に直す」人力ルールでしたが、いまは1か所です。

| 対象 | 正 | 検証 |
|---|---|---|
| プリセット種目のID・名前 | `packages/contract/preset_exercises.json` | `npm run verify:contract` |
| GraphQL スキーマ | `packages/contract/schema.graphql` | `rake graphql:verify` |
| ドメインの期待値 | `packages/contract/domain_cases.json` | 4言語の契約テスト |

配色と余白は各実装に残っています（`colors.ts` / `colors.dart` / `Theme.kt` / `tokens.css`）。

## データを扱うときの注意

- **削除は論理削除**（`deleted_at`）。物理削除にすると、オフラインキューが持っている
  削除済みルーティンへの記録が FK 違反で永久に送信失敗する
- **IDはクライアントで生成する。** 冪等性の土台で、再送しても二重登録されない
- **端末ごとに一意にする。** 固定UUIDを埋め込むと、サーバでは全端末が衝突する
  （初期ルーティンで実際に踏んだ）
- **ルーティンの更新は `lockVersion` を送る。** 送らないと後勝ちで上書きされる

## テストの実行

```bash
npm run verify:contract
```

```bash
cd nikkake_api && bundle exec rspec
```

```bash
cd nikkake_react_native && npm run verify
```

サーバモードの E2E は Rails が要ります。

```bash
cd nikkake_react_native && EXPO_PUBLIC_BACKEND=server npx playwright test
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
自動テストで担保できていない範囲が明記されています。
