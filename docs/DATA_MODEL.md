# データモデル

ローカルストレージとSupabaseで**同じ形**のレコードを持ちます。
ローカル保存もSupabaseの列名（snake_case）に合わせたJSONなので、同期時の変換が不要です。

## 共通フィールド

全エンティティが持ちます。

| フィールド | 型 | 用途 |
|---|---|---|
| `id` | uuid | クライアント生成。RFC 4122 v4 準拠 |
| `created_at` | timestamptz | 作成時刻 |
| `updated_at` | timestamptz | **同期の差分カーソルと衝突解決のキー** |
| `deleted_at` | timestamptz \| null | 論理削除。`null` 以外は画面に出さない |

`updated_at` の比較は必ず時刻としてパースしてから行います（理由は [ARCHITECTURE.md](ARCHITECTURE.md#衝突解決-last-write-wins)）。

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
| `user_id` | uuid? | **ローカル専用データは null**。サインイン後の同期で埋まる |
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
| `user_id` | uuid? | ローカル専用は null |
| `log_date` | date | `YYYY-MM-DD`。**日跨ぎの判定はこの値で行う** |
| `status` | text | `completed` / `partial` / `skipped` |
| `duration_sec` | int? | |
| `started_at` | timestamptz? | |
| `completed_at` | timestamptz? | |

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

**この値は3実装すべてに埋め込まれています。変更するときは必ず全部を同時に直してください。**

| ファイル |
|---|
| `nikkake_react_native/src/constants/exercises.ts` |
| `nikkake_flutter/lib/constants/exercises.dart` |
| `nikkake_kmp/shared/src/commonMain/kotlin/com/myapplication/common/constants/Exercises.kt` |
| `nikkake_react_native/supabase/migrations/20260801000000_local_first_sync.sql` |

### 初期ルーティンも固定ID

`00000000-0000-4000-8000-000000009001` = 「いつものルーティン」

### それ以外はクライアント生成のUUID v4

サーバに採番させると、オフラインでレコードを作れなくなるためです。

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
| `lastSyncedAt` | 差分同期のカーソル（前回の同期**開始**時刻） |
| `syncUserId` | 同期先アカウント。変わったらカーソルを捨てる |

## Supabase側のRLS

- `exercises` — プリセットは全員読める。カスタムは `created_by = auth.uid()` のみ
- `routines` / `routine_logs` — `user_id = auth.uid()` のみ
- `routine_exercises` / `exercise_logs` — 親を辿って所有者を確認

クライアントはDELETEを一切発行しません（論理削除なのでUPDATEになる）。

## マイグレーション

`nikkake_react_native/supabase/migrations/` にあります。

| ファイル | 内容 |
|---|---|
| `20260711000000_initial_setup.sql` | 初期スキーマ、RLS、プロフィール自動作成トリガー |
| `20260713000000_add_workout_rpcs.sql` | ワークアウト保存RPC（**現在は未使用**） |
| `20260801000000_local_first_sync.sql` | ローカルファースト化。同期用の列、プリセットIDの固定化、RPCの削除 |

3つ目の適用後、ワークアウトの保存はローカルで完結し、同期は素の upsert で行うため
RPC は不要になりました。
