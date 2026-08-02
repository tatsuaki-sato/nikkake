# 契約 — 5言語の一致をどう守るか

Ruby / TypeScript / Dart / Kotlin が同じ答えを返すことを、レビューではなく
**CIで機械的に**保証します。これがこのリポジトリの安全装置です。

## なぜ要るのか

移行前は同じ計算が3言語に別々に書かれており、実際に食い違っていました。

| 食い違い | 症状 |
|---|---|
| KMP だけタイムスタンプを文字列比較 | `.500Z` が `Z` より前になり、同期が取りこぼす |
| Ruby の重量表示が float の `to_s` 由来 | Web は「前回: 50.0×10」、RN は「前回: 50×10」 |
| プリセット種目の固定UUIDが4か所に手書き | 片方だけ足すと種目が紐付かない |

どれもテストは通っていました。**同じ期待値を各言語のテストにも書き写していた**からです。
期待値そのものを1本にしない限り、この種のズレは検出できません。

## 唯一の正

```
packages/contract/
├── schema.graphql          GraphQL スキーマ（9クエリ / 14ミューテーション / 57型）
├── preset_exercises.json   プリセット種目25件（固定UUID・名前・カテゴリ・アイコン）
├── domain_cases.json       ドメインの期待値（89ケース）
└── scripts/
    ├── verify-presets.mjs  各言語のプリセット定義が一致するか
    └── verify-schema.mjs   必要な操作と引数が揃っているか
```

## domain_cases.json

言語に依存しない形で「入力 → 期待される出力」だけを書きます。

```json
{
  "formatPreviousSets": {
    "description": "ワークアウト画面の「前回: …」に出す文字列。…",
    "cases": [
      { "name": "整数の重量に .0 を付けない",
        "sets": [{ "set_number": 1, "reps": 10, "weight": 50.0, "duration_sec": null }],
        "expect": "50×10" }
    ]
  }
}
```

これを4言語のテストが読みます。

| 言語 | テスト |
|---|---|
| Ruby | `nikkake_api/spec/domain/contract_spec.rb` |
| TypeScript | `nikkake_react_native/src/lib/__tests__/contract.test.ts` |
| Dart | `nikkake_flutter/test/contract_test.dart` |
| Kotlin | `nikkake_kmp/shared/src/desktopTest/.../ContractTest.kt` |

対象の関数群:

`calculateStreak` / `isRoutineDueToday` / `calculateDailyStats` /
`calculateExerciseProgress` / `calculateOverallStats` / `formatDuration` /
`formatWeight` / `formatFrequency` / `greetingForHour` / `formatPreviousSets`

DST境界（3月末・10月末）、うるう年、`23:59に記録 → 00:01に閲覧` を含めています。

### Kotlin だけ desktopTest に置いてある理由

common な Kotlin コードからはファイルを読めないためです。
Gradle のテスト作業ディレクトリはモジュール直下なので、契約ディレクトリの絶対パスは
`shared/build.gradle.kts` からシステムプロパティで渡しています。
相対パス頼みにすると、呼び出し元によって壊れます。

## スキーマの鮮度

生成物は放っておくと腐るので、実装との差分を検査します。

```bash
cd nikkake_api && bundle exec rake graphql:dump
git diff --exit-code ../packages/contract/schema.graphql
```

```bash
cd nikkake_api && bundle exec rake graphql:verify
```

`graphql:verify` が見ているもの:

- 契約にある操作が実装に全部あるか
- `home` / `progress` が `today` と `timeZone` を受け取るか（タイムゾーン設計の要）
- すべてのミューテーションの戻り値に `userErrors` があるか

## プリセット種目

```bash
npm run verify:contract
```

RN(TS) / Flutter(Dart) / KMP(Kotlin) / SQL の4つが `preset_exercises.json` と
一致しているかを検査します。ID・名前・カテゴリ・アイコン・並び順まで見ます。

固定UUID `00000000-0000-4000-8000-{12桁連番}` は変えないでください。
既存の記録が種目に紐付かなくなります。

## 検査そのものが効いているかを確かめる

検査は「壊したら落ちる」ことを確認しないと意味がありません。
このリポジトリの検査はすべて一度、意図的に壊して落ちることを確認済みです。

```
verify-presets.mjs   Flutter の定義を1文字変えて落ちることを確認
graphql:verify       契約から操作を1つ削って落ちることを確認
ContractTest.kt      Kotlin の × を * に変えて落ちることを確認
architecture_spec    Date.today を書いて落ちることを確認
```

新しく検査を足すときも、同じように一度壊してください。

## 仕様を変える手順

1. `packages/contract/` を直す
2. `nikkake_api/` を直して `bundle exec rspec` を通す
3. `rake graphql:dump` でスキーマを更新する
4. 各クライアントの契約テストを走らせ、落ちたところを直す

**期待値を書き換えて通すのは、仕様変更だと確信できるときだけ。**
落ちたら、まず実装側を疑ってください。
