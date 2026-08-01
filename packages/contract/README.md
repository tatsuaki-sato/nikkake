# @nikkake/contract

5実装（Rails / Web / React Native / Flutter / KMP）が共有する**唯一の契約**です。

ここを直したら各実装へ反映し、CI で一致を検査します。
逆に、各実装を直接編集して契約とズレると CI が落ちます。

## 中身

| ファイル | 役割 |
|---|---|
| `preset_exercises.json` | プリセット種目25件の固定UUIDと属性。**4か所の手書きコピーを廃止するための正** |
| `domain_cases.json` | ドメイン関数の期待値。5言語のテストがこれを読む |
| `schema.graphql` | GraphQL の契約。Rails 実装後は `rake graphql:dump` の出力と一致を検査する |
| `scripts/verify-presets.mjs` | プリセット種目が4か所で一致しているかを検証 |
| `scripts/verify-schema.mjs` | スキーマの構文と必須操作が揃っているかを検証 |

## 検証

```bash
cd packages/contract && npm run verify
```

ドメイン期待値の検証は各実装のテストが行います。

```bash
cd nikkake_react_native && npx jest src/lib/__tests__/contract.test.ts
```

Rails / Flutter / KMP 側の契約テストは移行の各フェーズで追加します。

## なぜ必要か

移行前、プリセット種目の固定UUIDは**4か所に手書きでコピー**されていました
（RN / Flutter / KMP の constants と SQL マイグレーション）。
`.agents/AGENTS.md` が「4か所同時に直せ」と人力ルールで守っている状態で、
実際に KMP だけタイムスタンプの比較方法が違ってバグっていた前例があります。

このパッケージは、その人力ルールを**機械チェックに格上げする**ためのものです。

## 注意

### プリセット種目のIDは変更しない

`00000000-0000-4000-8000-{12桁連番}` は全プラットフォーム共通の固定値です。
端末ごとにランダムなUUIDを振ると、クラウド同期したときに同じ種目が重複します。

やむを得ず変更する場合は、4実装とサーバのシードを同時に直し、
既存ユーザーのデータ移行も設計してください。

### 「今日」はサーバが計算しない

`schema.graphql` の `home` と `progress` が `today` と `timeZone` を必須引数に
取っているのは意図的です。サーバが `Date.today` を使うと、日本の朝8時が UTC では
前日23時なので即座に1日ずれ、**ストリークが1日ずれる**という最も致命的なバグになります。

`verify-schema.mjs` がこの引数の存在を検査しています。

### ドメイン期待値を減らさない

`domain_cases.json` のケースは現行実装の挙動から抽出したものです。
移行でケースが通らなくなった場合、**まず実装側を疑ってください**。
期待値を書き換えて通すのは、仕様変更だと確信できるときだけにしてください。
