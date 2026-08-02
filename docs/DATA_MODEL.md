# データモデル

PostgreSQL（Rails）が正です。端末のローカルストレージも**同じ形**のレコードを持ちます。
列名（snake_case）を揃えてあるので、遅延登録で預けるとき（`importSnapshot`）に変換が要りません。

GraphQL の応答だけは camelCase です（`packages/contract/schema.graphql`）。

## 共通フィールド

全エンティティが持ちます。

| フィールド | 型 | 用途 |
|---|---|---|
| `id` | uuid | クライアント生成。RFC 4122 v4 準拠 |
| `created_at` | timestamptz | 作成時刻 |
| `updated_at` | timestamptz | 読みキャッシュの差分カーソル |
| `deleted_at` | timestamptz \| null | 論理削除。`null` 以外は画面に出さない |

`updated_at` は移行前は衝突解決（last-write-wins）のキーでしたが、
書き手がサーバ1つになったので役割が変わりました。衝突解決には `routines.lock_version` を使います。

### 論理削除をやめてはいけない

物理削除にすると、オフラインキューが持っている「削除済みルーティンへの記録」が
外部キー違反になり、**永久に送信失敗し続けます**。
移行前は「削除が他端末へ伝わらない」のが理由でしたが、いまは理由が変わっただけで必須のままです。

## テーブル

### exercises — 種目マスタ

| 列 | 型 | 備考 |
|---|---|---|
| `name` | text | 「ベンチプレス」など |
| `category` | text | `strength` / `cardio` / `game` / `custom` |
| `description` | text? | |
| `icon` | text? | 絵文字 |
| `is_preset` | bool | プリセットは全ユーザー共有 |
| `created_by` | uuid? | カスタム種目の作成者 |

### routines — ルーティン定義

| 列 | 型 | 備考 |
|---|---|---|
| `user_id` | uuid | **NOT NULL**。匿名ユーザーも実在レコードなので null を許さない |
| `name` | text | |
| `description` | text? | |
| `color` | text | `#RRGGBB` |
| `icon` | text | 絵文字 |
| `frequency_type` | text | `daily` / `every_n_days` / `weekly` |
| `frequency_value` | int | `every_n_days` のときの間隔 |
| `frequency_days` | int[] | `weekly` のときの曜日。**日=0 〜 土=6** |
| `preferred_time` | time? | 未使用（通知機能で使う予定） |
| `is_active` | bool | false なら一覧では薄く表示、ホームには出ない |
| `sort_order` | int | 一覧の並び順 |
| `lock_version` | int | 楽観ロック。更新時に送り、古ければ CONFLICT で弾く |

### routine_exercises — ルーティン内の種目

| 列 | 型 | 備考 |
|---|---|---|
| `routine_id` | uuid | |
| `exercise_id` | uuid | |
| `sort_order` | int | ルーティン内の順番 |
| `target_sets` | int | |
| `target_reps` | int? | |
| `target_weight` | real? | null は自重 |
| `target_duration_sec` | int? | **非nullなら時間計測の種目**（プランクなど） |
| `rest_sec` | int? | セット間の休憩秒数 |
| `notes` | text? | |

ルーティンを編集すると、この行は**丸ごと作り直されます**（既存を論理削除して再挿入）。
差分更新にすると並び順の入れ替えが複雑になるためです。

### routine_logs — ワークアウト1回分

| 列 | 型 | 備考 |
|---|---|---|
| `routine_id` | uuid | |
| `user_id` | uuid | NOT NULL。全テーブルに非正規化してある（毎クエリのJOINを避けるため） |
| `log_date` | date | `YYYY-MM-DD`。**クライアントが決めて送る。サーバは導出しない** |
| `status` | text | `completed` / `partial` / `skipped`。**完了セット数からサーバが判定する** |
| `duration_sec` | int? | |
| `started_at` | timestamptz? | |
| `completed_at` | timestamptz? | |
| `client_time_zone` | text? | 記録時の端末のTZ（例 `Asia/Tokyo`）|
| `client_utc_offset_minutes` | int? | 記録時のオフセット（例 540）|

`client_time_zone` と `client_utc_offset_minutes` は、日付がずれた記録を後から救済するために持ちます。
これが無いと検証も修正もできません（[ARCHITECTURE.md](ARCHITECTURE.md#原則3-記録時のタイムゾーンを保存する)）。

`status` はクライアントから受け取りません。完了セット数と総セット数から必ずサーバが決めます。
呼び出し側に決めさせると、判定基準がずれても誰も気づけないためです。

同じ日に同じルーティンを2回やった場合は、上書きではなく2行になります。

### exercise_logs — セット1本分

| 列 | 型 | 備考 |
|---|---|---|
| `routine_log_id` | uuid | |
| `routine_exercise_id` | uuid? | 参照先が消えても null になるだけ |
| `exercise_id` | uuid | **履歴グラフはこちらを使う** |
| `set_number` | int | 1始まり |
| `actual_reps` | int? | |
| `actual_weight` | real? | |
| `actual_duration_sec` | int? | |

`exercise_id` を持たせているのが要点です。`routine_exercises` はルーティン編集のたびに
作り直されるので、そこ経由で履歴を辿ると編集した時点でグラフが途切れます。

保存されるのは**完了にしたセットだけ**です。チェックを入れなかったセットは記録されません。

## ID規約

### プリセット種目は固定ID

```
00000000-0000-4000-8000-{12桁ゼロ埋めの連番}
```

例: 腕立て伏せ = `00000000-0000-4000-8000-000000000003`

端末ごとにランダムなUUIDでプリセットを作ると、クラウド同期したときに
同じ「腕立て伏せ」が複数生まれてしまいます。

**正は `packages/contract/preset_exercises.json` の1か所だけです。**
各言語の定義がそれと一致しているかは `npm run verify:contract` が検査します
（[CONTRACT.md](CONTRACT.md)）。

### 初期ルーティンのIDは固定しない

以前は `00000000-0000-4000-8000-000000009001` を全端末で共有していました。
ローカル完結なら無害でしたが、サーバへ預けるいまは**全端末が同じIDを送る**ことになり、
主キー衝突で2人目以降の初期ルーティンが黙って消えます。

端末ごとに採番してください。RN / Flutter / KMP の3つとも同じ問題を持っていました。

### それ以外もクライアント生成のUUID v4

サーバに採番させるとオフラインでレコードを作れなくなり、
さらに**冪等性の土台が失われます**。再送しても同じIDなので二重登録されない、
というのがオフラインキューの前提です。

## プリセット種目一覧（25件）

| # | 名前 | カテゴリ | 自重 | 時間計測 |
|---|---|---|:---:|:---:|
| 1 | ベンチプレス | strength | | |
| 2 | ダンベルフライ | strength | | |
| 3 | 腕立て伏せ | strength | ✓ | |
| 4 | インクラインベンチプレス | strength | | |
| 5 | デッドリフト | strength | | |
| 6 | ラットプルダウン | strength | | |
| 7 | 懸垂 | strength | ✓ | |
| 8 | ベントオーバーロウ | strength | | |
| 9 | スクワット | strength | ✓ | |
| 10 | レッグプレス | strength | | |
| 11 | レッグカール | strength | | |
| 12 | カーフレイズ | strength | ✓ | |
| 13 | ショルダープレス | strength | | |
| 14 | サイドレイズ | strength | | |
| 15 | ダンベルカール | strength | | |
| 16 | トライセプスエクステンション | strength | | |
| 17 | 腹筋（クランチ） | strength | ✓ | |
| 18 | プランク | strength | ✓ | ✓ |
| 19 | レッグレイズ | strength | ✓ | |
| 20 | ランニング | cardio | ✓ | ✓ |
| 21 | エアロバイク | cardio | | ✓ |
| 22 | 縄跳び | cardio | ✓ | ✓ |
| 23 | リングフィット | game | | ✓ |
| 24 | フィットボクシング | game | | ✓ |
| 25 | Just Dance | game | | ✓ |

## 初期ルーティン「いつものルーティン」

初回起動時に自動で入ります。器具なしで自宅でできる種目だけで構成されています。

| 種目 | セット | 回数/秒 | 休憩 |
|---|---|---|---|
| 腕立て伏せ | 3 | 10回 | 60秒 |
| スクワット | 3 | 15回 | 60秒 |
| 腹筋（クランチ） | 3 | 20回 | 45秒 |
| プランク | 2 | 30秒 | 45秒 |

投入は `meta.seeded` フラグで**1度だけ**です。ユーザーが削除したあとに復活すると鬱陶しいためです。
プリセット種目だけは、アプリ更新で増えることがあるので毎回差分を補います。

## ローカルのメタ情報

`nikkake:v1:meta` に保存されます。

| フィールド | 用途 |
|---|---|
| `schemaVersion` | 将来のマイグレーション用 |
| `seeded` | 初期ルーティンを投入済みか |
| `snapshotImportedAt` | 端末のデータをサーバへ預けた日時。**一度入ったら二度と送らない** |

`snapshotImportedAt` を無視して毎回預け直すと、
サーバ側で消したはずのルーティンが端末のコピーから復活します。

## 認証まわり

| テーブル | 用途 |
|---|---|
| `users` | 匿名でも実在する。`email` / `password_digest` は昇格時に埋まる |
| `api_tokens` | `token_digest`（SHA-256）だけを保存。生トークンは発行時にしか存在しない |
| `mutation_receipts` | 冪等性の補助。`(user_id, key)` にユニーク制約 |

メール登録への昇格で `user.id` は変わりません。したがって**データ移行が発生しません**。

## 認可

`Routine.find(id)` を書ける状態にしないことが主防御です。必ず `current_user` から
association を辿ります。`nikkake_api/spec/architecture_spec.rb` が機械的に検査しています。

存在しないIDと他人のIDは同じ `NOT_FOUND` を返します（IDの存在有無を漏らさないため）。

PostgreSQL の RLS を最終防壁として残すかは、本番前に判断します。

## マイグレーション

`nikkake_api/db/migrate/` が正です。本番データが無かったので最終形1本で切り直しました。

`nikkake_react_native/supabase/migrations/` は移行前の名残で、
プリセット種目の固定UUIDの出所としてのみ意味があります（内容は契約へ移設済み）。
