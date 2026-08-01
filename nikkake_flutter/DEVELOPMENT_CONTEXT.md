# nikkake — Flutter

React Native 版（リファレンス実装）に追従する実装です。

全体設計は [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)、
機能仕様は [../docs/FEATURES.md](../docs/FEATURES.md) を参照。

## 技術スタック

| 用途 | 採用 |
|---|---|
| フレームワーク | Flutter 3.44 / Dart 3.12 |
| 状態管理 | Provider (ChangeNotifier) |
| 画面遷移 | Navigator + MaterialPageRoute |
| ローカル保存 | shared_preferences |
| ID生成 | uuid |
| バックアップ | supabase_flutter |
| テスト | flutter_test / integration_test |

`go_router` は依存に残っていますが使っていません。遷移が
「4タブ＋上に重ねる数枚」だけなので、素の Navigator で足りています。

## ディレクトリ

```
lib/
├── main.dart               起動。ストレージ初期化とSupabase初期化（失敗しても続行）
├── app.dart                ウィジェットツリー。テストから同じ構成を組める
├── constants/              配色、プリセット種目、初期ルーティン
├── models/models.dart      全ドメインモデル（JSONキーはSupabaseの列名に一致）
├── data/
│   ├── local_store.dart    SharedPreferencesのラッパ（メモリキャッシュ付き）
│   ├── local_db.dart       コレクションのCRUD、論理削除、差分抽出
│   ├── repository.dart     画面が使うドメインAPI
│   └── sync_service.dart   Supabaseとの双方向同期
├── domain/
│   ├── date_utils.dart     日付・表示フォーマット（純粋関数）
│   └── stats.dart          ストリーク・集計（純粋関数）
├── providers/
│   ├── app_state.dart      ルーティンとログの読み取り状態
│   ├── auth_controller.dart 任意サインインと同期状態
│   └── workout_controller.dart 実行中のワークアウト
├── screens/                各画面
└── widgets/ui.dart         共通の部品
```

## 起動と実行

```bash
flutter pub get
flutter run
```

## テスト

```bash
flutter analyze
flutter test                     # 101件（単体＋シナリオ、ヘッドレス）
flutter test integration_test    # 同じシナリオを実機/シミュレータで
```

シナリオ本体は `test/scenarios.dart` の1ファイルに集約してあり、
ヘッドレス版（`test/app_test.dart`）と実機版（`integration_test/app_test.dart`）が
**同じ手順**を共有します。

## この実装に固有の事情

### ウィジェットテストのビューポート

既定の 800×600 だとルーティン作成フォームが縦に収まりません。
Flutterは画面外のウィジェットをビルドしないので、そのままだとタップできません。
`pumpApp` で 1200×4000 に広げています。テストごとにスクロール操作を挟むより意図が読めます。

```dart
tester.view.physicalSize = const Size(1200, 4000);
tester.view.devicePixelRatio = 1.0;
addTearDown(tester.view.reset);
```

### AuthController は null 許容で受ける

`SettingsScreen` は `context.watch<AuthController?>()` で読みます。

- Supabase の初期化に失敗した場合（`main.dart` が握りつぶす）
- 認証を組み込まないテスト環境

どちらでも `AuthController` が存在しないので、必須にすると
`ProviderNotFoundException` でクラッシュします。ローカルモードとして通常どおり表示します。

### 曜日の変換

Dart の `DateTime.weekday` は **月=1 … 日=7** ですが、DBは **日=0 … 土=6** です。
`today.weekday % 7` で変換しています（`date_utils.dart` と `progress_screen.dart`）。

### null を明示的に代入するための copyWith

`WorkoutSet.copyWith` は `clearReps` / `clearWeight` / `clearDuration` フラグを持ちます。
通常の `copyWith` では「nullを設定する」と「変更しない」が区別できないためです。

### Supabase の publishableKey

`supabase_flutter` 2.16 以降、`anonKey` は非推奨で `publishableKey` が正式名称です。
値は同じ anon キーです。

### グラフはContainerの高さで描いている

進捗画面のグラフとカレンダーはグラフライブラリを使わず、
`Container` の高さと色だけで表現しています。3実装で見た目を揃えやすいためです。
