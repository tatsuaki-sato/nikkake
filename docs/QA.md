# QA

検証結果と、検証中に見つけた不具合の記録。
「何が終わっていて何が残っているか」の全体計画は [ROADMAP.md](ROADMAP.md) を見ること。

## 最新の実行結果

実行日: 2026-08-02 / 環境: macOS 15 (Apple Silicon), Ruby 4.0.6, Rails 8.1.3.1,
PostgreSQL 16.14, Node 22, Flutter 3.44.6 (Dart 3.12.2), JDK 17.0.19

### 契約（言語をまたぐ一致）

| 項目 | コマンド | 結果 |
|---|---|---|
| プリセット種目 | `npm run verify:contract` | ✅ 25件が RN / Flutter / KMP / SQL の4か所で一致 |
| GraphQLスキーマ | 同上 | ✅ Query 9本 / Mutation 14本 / 型 57個 |
| 契約と実装の差 | `rake graphql:verify` | ✅ 一致 |

### Rails API

| 項目 | コマンド | 結果 |
|---|---|---|
| 全テスト | `bundle exec rspec` | ✅ **137 examples, 0 failures** |

### Web (PC/SP)

| 項目 | コマンド | 結果 |
|---|---|---|
| E2E | `npx playwright test` | ✅ **26 passed** (chromium 13 + Mobile Chrome 13) |

### React Native

| 項目 | コマンド | 結果 |
|---|---|---|
| 型チェック | `npx tsc --noEmit` | ✅ エラー0 |
| 単体テスト | `npx jest` | ✅ **181 passed** / 8 suites |
| E2E（ローカルモード） | `npx playwright test` | ✅ **84 passed** |
| E2E（サーバモード） | `EXPO_PUBLIC_BACKEND=server npx playwright test` | ✅ **84 passed** |

サーバモードは実際に Rails へ届いていることを DB で確認済みです
（記録した重量 50 / 37 / 47 が `exercise_logs` に入っている。
全ユーザーの「いつものルーティン」がちょうど1件ずつ）。

### Flutter

| 項目 | コマンド | 結果 |
|---|---|---|
| 静的解析 | `flutter analyze` | ✅ No issues found |
| 単体＋シナリオ | `flutter test` | ✅ **192 passed** |

サーバ実装は応答を差し替えたテストで検証しています（13件）。
**`flutter test` は HTTP を差し替えるため、実サーバとの疎通は確認できません。**
Flutter の実通信は未検証です。

### Kotlin Multiplatform

| 項目 | コマンド | 結果 |
|---|---|---|
| 単体テスト（desktop） | `./gradlew :shared:desktopTest` | ✅ **83 passed** / 0 failures |

**合計 703 テスト、全てグリーン。**

### この回で見つけて直した不具合

いずれも移行作業の途中で表に出たものです。

| 内容 | 影響 |
|---|---|
| Dart の `DateTime.timeZoneName` が `Asia/Tokyo` ではなく `JST` を返す | `users.time_zone` に解決できない値が保存されていた。IANA名を取るようにし、サーバ側でも既定へ寄せるようにした |
| 「前回: …」の重量が Ruby では `50.0×10`、TypeScript では `50×10` | Web と RN で表示文言が食い違う。契約に11ケース足して4言語で検証するようにした |
| 初期ルーティンのIDが全端末で同じ固定UUID | サーバでは主キー衝突で**2人目以降の初期ルーティンが黙って消える**。RN / Flutter / KMP の3つとも該当 |
| `createAnonymousAccount` が初期ルーティンを作らなかった | Web の新規ユーザーがホーム空。「起動したらすぐルーティン」の絶対条件に違反 |
| 登録完了前に操作すると記録が端末に取り残された | 預け入れとサーバ切り替えのあいだが空いていた。切り替え後に預け直して塞いだ |
| 設定画面の件数と初期化が旧 sync.ts のまま | サーバモードで**初期化しても何も消えていなかった** |
| ワークアウト画面が古いキャッシュを見て「前回の記録」が入らなかった | Web |

### 検査そのものを壊して確かめたもの

通っている検査が本当に効いているかは、一度壊さないと分かりません。

| 検査 | 壊し方 | 落ちた |
|---|---|---|
| `verify-presets.mjs` | Flutter の定義を1文字変更 | ✅ |
| `rake graphql:verify` | 契約から操作を1つ削除 | ✅ |
| `ContractTest.kt` | Kotlin の `×` を `*` に変更 | ✅ |
| `architecture_spec.rb` | サービスに `Date.today` を追加 | ✅ |

---

## 未検証・既知の問題（詳細）

一覧と優先順位は [ROADMAP.md](ROADMAP.md) にまとめてある。ここには詳細だけ残す。

### 契約(schema.graphql)と実装の乖離検知が壊れている

`rake graphql:dump` が `schema.generated.graphql` に書くのに、CIは
`schema.graphql` を diff していて常に無変更＝ノーオペレーションになっていた。
実際に `createAnonymousAccount` の引数形が契約(`input:`)と実装(フラット引数)で
食い違っていたが検知されなかった。クライアント側は全実装とも正しい
（実装と同じ）形で呼んでいるため、アプリとしての実害は無い。

### docker-compose.yml で見つけた不具合（2026-08-10）

初めて実際に動かして見つかったもの。いずれも修正済み:

1. `db` のヘルスチェックが `pg_isready -U nikkake`（DB名省略）で、存在しない `nikkake` DBを見に行っていて永遠に unhealthy → `-d nikkake_development` を追加
2. `api` の `ports: "3000:3000"` が、コンテナ内の実際の待受（Thrusterの80番、Pumaはループバックの3000番）と食い違っていて外から繋がらない → `"3000:80"` に修正
3. `bin/docker-entrypoint` が `db:prepare`（マイグレーション）だけでプリセット種目の `db:seed` を呼んでおらず、起動直後は種目0件 → `db:seed` を追加
4. **上記3のdb:seedを追加した結果、apiコンテナが `Exited (1)` で落ちるようになった。** `lib/domain/preset_exercises.rb` が `packages/contract/preset_exercises.json`（モノレポの兄弟ディレクトリ）を実行時に読むが、`docker-compose.yml` のビルドコンテキストが `./nikkake_api` だけだったため `packages/contract` がイメージに含まれていなかった（`Errno::ENOENT`）。**このDockerfileは本番(Render)でもそのまま使う予定だったので、直さなければ本番デプロイも同じ理由で落ちていた。** ビルドコンテキストをリポジトリルートに変更し、ルートに `.dockerignore` を新設、`Dockerfile` のCOPY元パスと `packages/contract` の取り込みを追加して修正。再ビルドで動作確認済み・コミット・push・CI green まで完了。

### Renderへの本番デプロイで見つかった不具合（2026-08-22）

初めて実際にRender + Supabaseへデプロイして見つかったもの。

1. **DATABASE_URLのパスワードに `@` が含まれていて、URLとしてパース不能だった。** `postgres://user:pa@ss@host` のように `@` が2つ以上現れると、どこまでがパスワードか判別できずRailsが `URI::InvalidURIError` で起動時に落ちる。パスワード中の `@` を `%40` にURLエンコードして解消。デプロイ時に使う接続文字列は毎回このエンコードが必要（Supabase側はパスワードを生成する際に記号を含めることがある）
2. **SupabaseのDirect connection（`db.xxx.supabase.co`）がIPv6アドレスにしか解決されず、RenderからはIPv6の発信接続ができず `Network is unreachable` で落ちた。** SupabaseのSession pooler（`aws-0-<region>.pooler.supabase.com`、ユーザー名は `postgres.<project-ref>` 形式）に切り替えて解消。Transaction poolerではなくSession poolerを使う理由は、RailsのPrepared StatementがTransaction poolerのコネクション使い回しと相性が悪いため
3. **`config/database.yml` のproduction環境で `cache`/`queue`/`cable` が `primary` と別データベースとして定義されていたが、bareの `DATABASE_URL` 環境変数はRailsの規約上 `primary` にしか自動適用されない。** `cache`/`queue`/`cable` にはホスト情報が無いままとなり、ソケット接続にフォールバックして `db:prepare` がそこで毎回落ちていた（`primary` 自体は正しく繋がっていたため、原因特定に時間がかかった）。4つとも同じ `DATABASE_URL` を明示的に使うよう `url: <%= ENV["DATABASE_URL"] %>` に統一して解消（コミット `c43e42d`）

いずれも修正済み。2026-08-22時点で `https://nikkake-api.onrender.com` が稼働中で、匿名アカウント作成・認証つきGraphQLクエリ・プリセット種目25件の取得まで確認済み。

---

## リリース前チェックリスト

### 1. 契約と自動テスト

- [ ] `npm run verify:contract`
- [ ] `cd nikkake_api && bundle exec rspec`
- [ ] `cd nikkake_api && bundle exec rake graphql:verify`
- [ ] `cd nikkake_react_native && npm run verify`
- [ ] `cd nikkake_react_native && EXPO_PUBLIC_BACKEND=server npx playwright test`
- [ ] `cd nikkake_flutter && flutter run --dart-define=BACKEND=server`（実機/実サーバで手動確認）
- [ ] `cd nikkake_web && npx playwright test`
- [ ] `cd nikkake_flutter && flutter analyze && flutter test`
- [ ] `cd nikkake_kmp && ./gradlew :shared:desktopTest`

サーバモードの E2E は、通ったあとに DB の中身も見てください。
CORS を設定し忘れると遅延登録が黙って失敗し、**ローカルモードのまま全部通ります**。

### 2. バックエンド

- [ ] マイグレーションが適用されている
- [ ] プリセット種目25件が固定IDで入っている（`PresetSyncer`）
- [ ] `CORS_ORIGINS` が本番のオリジンだけを許可している
- [ ] `RAILS_MASTER_KEY` が設定されている
- [ ] アプリのホスティング先と DB が同じリージョンにある

### 3. 手動確認（実装ごと・実機で）

**起動（最重要）**

- [ ] アプリを削除してから入れ直し、**サインインせずに**起動できる
- [ ] 起動直後のホームに「いつものルーティン」が出ている
- [ ] タップするとその場でワークアウトが始まる
- [ ] **どこにもログイン画面が出てこない**
- [ ] **機内モードのまま新規インストールして、上記が全て動く**（遅延登録の核心）
- [ ] そのあとオンラインに戻すと、機内モード中の記録がサーバに現れる

**ルーティン**

- [ ] 作成 → ホームと一覧の両方に出る
- [ ] 名前空 / 種目0件 / 曜日未選択 でそれぞれエラーが出て保存されない
- [ ] 編集 → 内容が保存される。過去の記録が消えていない
- [ ] 停止 → ホームから消える。一覧では薄く「停止中」
- [ ] 削除 → 確認ダイアログが出る。記録は残る
- [ ] **オフラインでは作成・編集ができない旨が出る**（仕様どおりの機能後退）

**ワークアウト**

- [ ] セット完了で休憩タイマーが自動で始まる
- [ ] タイマーをタップでスキップできる
- [ ] 時間種目（プランク）で秒の入力欄になる
- [ ] セットの増減ができる。1本未満にはならない
- [ ] 完了 → サマリーが出て、連続記録が更新される
- [ ] 中断 → 何も保存されない
- [ ] 2回目に開始すると前回の値が初期値に入っている
- [ ] 「前回: 50×10 / 50×9」の文言が4実装で同じ
- [ ] オフラインで記録 → 復帰後に送られる

**進捗**

- [ ] 記録0件で空状態
- [ ] 1回記録すると集計・グラフ・カレンダーが出る
- [ ] 7日/30日の切り替えが効く
- [ ] 種目を切り替えると推移が変わる

**設定**

- [ ] 件数が実際のデータと合っている
- [ ] データ初期化 → 確認後、初期状態に戻る（**サーバ側も消える**）

**タイムゾーン**

- [ ] 端末のTZを Pacific/Honolulu にして記録 → その端末の日付で入る
- [ ] 23:59 に記録して 00:01 に開く → ストリークが切れていない
- [ ] 端末のTZを変えても、過去の記録の日付が動かない

### 4. アカウント（任意機能）

- [ ] 匿名で数件記録してからメール登録 → **その記録がそのまま残る**（IDが変わらないので移行が無い）
- [ ] 別端末で同じアカウントにサインイン → 記録が見える
- [ ] サインアウトしても端末の閲覧用データが壊れない

### 5. 実装間のパリティ

- [ ] 同じ初期ルーティンが同じ内容で入っている
- [ ] バリデーションと表示の文言が全部同じ
- [ ] 配色・余白が揃っている
- [ ] ストリークの数え方が同じ（同じ操作をして同じ日数になる）

---

## 既知の注意点

### サーバモードのE2Eは静かに嘘をつく

CORS が未設定だと、遅延登録は設計どおり例外を投げずに失敗し、
アプリはローカルモードのまま完動します。E2E は全部通ります。
**サーバ経路を確かめたときは必ず DB の中身も見てください。**

### KMPのビルドに必要なもの

- JDK 17（`JAVA_HOME` を設定）
- Androidターゲットをビルドするなら Android SDK（`local.properties` の `sdk.dir` か `ANDROID_HOME`）

`local.properties` は `.gitignore` 済みなので、クローン後に各自で作る必要があります。

### RNのE2Eを書くときの落とし穴

expo-router のWeb実装ではタブを切り替えても前の画面のDOMが残ります。
画面コンテナのtestIDでスコープを切らないと strict mode violation になります。
固定UUIDでウィジェットを引くのも駄目です（初期ルーティンのIDは端末ごとに変わります）。

### Flutterのウィジェットテストのビューポート

既定の 800×600 だとルーティン作成フォームが縦に収まらず、画面外のウィジェットは
ビルドされないためタップできません。`pumpApp` で 1200×4000 に広げています。

