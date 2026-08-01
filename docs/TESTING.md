# テスト

## 方針

- **ロジックは純粋関数に寄せて単体テストで守る**（日付判定・統計・同期の衝突解決）
- **画面はアプリ全体を起動するシナリオテストで守る**（部品単位のスナップショットは撮らない）
- **同期テストでは実ネットワークを叩かない**（Supabaseクライアントをモックに差し替える）
- **E2Eは認証をモックしない**。サインイン不要の設計なので、そもそも準備が要らない

## 全体像

| 実装 | 単体 | 結合/E2E | 合計 |
|---|---:|---:|---:|
| React Native | 91 (Jest) | 84 (Playwright ×2ブラウザ) | 175 |
| Flutter | 76 (flutter test) | 25 (ウィジェットシナリオ) | 101 |
| KMP | 77 (kotlin.test) | — | 77 |

最新の実行結果は [QA.md](QA.md) を参照。

---

## React Native

```bash
cd nikkake_react_native
npm run typecheck   # tsc --noEmit
npm test            # Jest（単体）
npm run test:e2e    # Playwright（E2E）
npm run verify      # 上記3つを順に実行
```

### 単体テスト（Jest）

`src/**/__tests__/*.test.ts`

| ファイル | 対象 |
|---|---|
| `lib/__tests__/utils.test.ts` | 日付計算、頻度判定、表示フォーマット |
| `lib/__tests__/stats.test.ts` | ストリーク、日別集計、種目別推移 |
| `lib/__tests__/localDb.test.ts` | CRUD、論理削除、差分抽出、last-write-wins |
| `lib/__tests__/repository.test.ts` | 初期シード、ルーティンCRUD、ワークアウト保存 |
| `lib/__tests__/sync.test.ts` | push/pull、衝突解決、エラー分類 |
| `stores/__tests__/workoutStore.test.ts` | セット操作、レストタイマー、完了判定 |

AsyncStorage は `jest.setup.js` でインメモリ実装に差し替えています。

> `jest.mock()` のファクトリは外部変数を参照できません。参照させたい変数は
> `mock` プレフィックスを付ける必要があります（`mockStorageMap` など）。

### E2E（Playwright）

`e2e/*.spec.ts`。Expo の Web ビルドに対して chromium と Mobile Chrome の2つで実行します。
`playwright.config.ts` の `webServer` が dev server を自動起動するので、事前準備は不要です。

| ファイル | シナリオ |
|---|---|
| `startup.spec.ts` | 未サインインで起動、初期ルーティンの存在、リロード後も残る |
| `routine.spec.ts` | 作成/編集/削除/停止、バリデーション、並べ替え |
| `workout.spec.ts` | 開始、レストタイマー、セット増減、完了/中断、前回値の引き継ぎ |
| `progress.spec.ts` | 空状態、集計、期間切り替え、種目別推移 |
| `settings.spec.ts` | 保存先の表示、サインイン導線、データ初期化 |

**書くときの注意**

- expo-router のWeb実装では**タブを切り替えても前の画面のDOMが残ります**。
  必ず画面コンテナのtestIDでスコープを切ってから探してください。

  ```ts
  await expect(page.getByTestId('routines-screen').getByText('いつものルーティン')).toBeVisible();
  ```

- タブは `<a role="tab">` として描画されます（`helpers.ts` の `openTab`）
- ブラウザコンテキストはテストごとに新規なので、localStorage は毎回空＝初回起動状態から始まります

---

## Flutter

```bash
cd nikkake_flutter
flutter analyze
flutter test                     # 単体＋シナリオ（ヘッドレス）
flutter test integration_test    # 同じシナリオを実機/シミュレータで
```

| ファイル | 対象 |
|---|---|
| `test/date_utils_test.dart` | 日付計算、頻度判定、表示フォーマット |
| `test/stats_test.dart` | ストリーク、日別集計、種目別推移 |
| `test/local_db_test.dart` | CRUD、論理削除、差分抽出、last-write-wins |
| `test/repository_test.dart` | 初期シード、ルーティンCRUD、ワークアウト保存 |
| `test/workout_controller_test.dart` | セット操作、レストタイマー、完了判定 |
| `test/scenarios.dart` | **アプリ全体のシナリオ（本体）** |
| `test/app_test.dart` | シナリオをヘッドレスで実行 |
| `integration_test/app_test.dart` | 同じシナリオを実機で実行 |

シナリオを1ファイルに集約してあるので、ヘッドレスと実機で**同じ手順**が走ります。

**書くときの注意**

- `pumpApp` でビューポートを 1200×4000 に広げています。既定の 800×600 だと
  ルーティン作成フォームが縦に収まらず、画面外のウィジェットはビルドされないため
  タップできません
- 同じ文字列が画面内に複数ある場合は `textOf(tester, 'key')` でキー指定して検証します
- `SharedPreferences.setMockInitialValues({})` でストレージをインメモリにします

---

## KMP

```bash
cd nikkake_kmp
./gradlew :shared:desktopTest          # 単体テスト
./gradlew :shared:compileKotlinIosSimulatorArm64   # iOSのコンパイル確認
./gradlew :shared:compileDebugKotlinAndroid        # Androidのコンパイル確認
```

JDK 17 が必要です。Androidターゲットには Android SDK も要ります
（`local.properties` の `sdk.dir` か `ANDROID_HOME`）。

| ファイル | 対象 |
|---|---|
| `commonTest/.../DateUtilsTest.kt` | 日付計算、頻度判定、表示フォーマット |
| `commonTest/.../StatsTest.kt` | ストリーク、日別集計、種目別推移 |
| `commonTest/.../LocalDbTest.kt` | CRUD、論理削除、差分抽出、last-write-wins、UUID形式 |
| `commonTest/.../RepositoryTest.kt` | 初期シード、ルーティンCRUD、ワークアウト保存 |
| `commonTest/.../WorkoutStoreTest.kt` | セット操作、レストタイマー、完了判定 |

ストレージは `StorageAdapter.inMemory()` に差し替えています（`TestHelpers.kt`）。

Compose UI テストは未整備です。`compose.uiTest` が現行の Compose 1.5.11 で解決できないため、
画面の検証は RN の Playwright と Flutter のシナリオテストでカバーしています。

---

## 3実装で対応するテスト

同じ仕様を検証しているテストは、名前も揃えてあります。仕様変更時は3か所とも直してください。

| 検証内容 | RN | Flutter | KMP |
|---|---|---|---|
| 未サインインで初期ルーティンがある | `repository.test.ts` | `repository_test.dart` | `RepositoryTest.kt` |
| 途中までの記録も今日の分は済んだ扱い | 〃 | 〃 | 〃 |
| 中断だけなら未実施のまま | 〃 | 〃 | 〃 |
| ルーティン編集後も履歴が残る | 〃 | 〃 | 〃 |
| partialでもストリークが途切れない | `stats.test.ts` | `stats_test.dart` | `StatsTest.kt` |
| 昨日までならストリーク継続 | 〃 | 〃 | 〃 |
| last-write-wins | `localDb.test.ts` | `local_db_test.dart` | `LocalDbTest.kt` |
| 論理削除は生データに残る | 〃 | 〃 | 〃 |
| レストタイマーが自動で走る | `workoutStore.test.ts` | `workout_controller_test.dart` | `WorkoutStoreTest.kt` |
| セットは1本未満にできない | 〃 | 〃 | 〃 |

KMP の `LocalDbTest` には他2実装に無いテストが1つあります
（小数秒の有無でタイムスタンプの前後が逆転しないこと）。
Kotlin では文字列比較になりやすい箇所なので、そこだけ明示的に守っています。
