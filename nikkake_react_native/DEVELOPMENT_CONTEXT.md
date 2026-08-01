# nikkake — React Native / Expo

3実装の**リファレンス実装**です。仕様変更はまずここに入れます。

全体設計は [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)、
機能仕様は [../docs/FEATURES.md](../docs/FEATURES.md) を参照。

## 技術スタック

| 用途 | 採用 |
|---|---|
| フレームワーク | Expo SDK 57 / React Native 0.86 |
| 画面遷移 | Expo Router（ファイルベース） |
| ローカル保存 | AsyncStorage v3 |
| サーバ状態 | TanStack Query（クエリ先はローカルストレージ） |
| クライアント状態 | Zustand |
| バックアップ | @supabase/supabase-js |
| テスト | Jest (jest-expo) / Playwright |

## ディレクトリ

```
src/
├── app/                    Expo Router の画面
│   ├── _layout.tsx         起動時のシード投入とルート定義
│   ├── (tabs)/             ホーム / ルーティン / 進捗 / 設定
│   ├── (auth)/             サインイン / アカウント作成（設定からのみ到達）
│   ├── routine/            作成 / 編集
│   └── workout/            実行 / サマリー
├── components/
│   ├── ui.tsx              共通の部品（Button, Card, EmptyState …）
│   └── RoutineForm.tsx     作成と編集で共通のフォーム
├── constants/              配色、プリセット種目、初期ルーティン
├── lib/
│   ├── storage.ts          AsyncStorageのラッパ（メモリキャッシュ付き）
│   ├── localDb.ts          コレクションのCRUD、論理削除、差分抽出
│   ├── repository.ts       画面が使うドメインAPI
│   ├── seed.ts             初回起動時のデータ投入
│   ├── sync.ts             Supabaseとの双方向同期
│   ├── stats.ts            ストリーク・集計（純粋関数）
│   ├── utils.ts            日付・表示フォーマット（純粋関数）
│   └── id.ts               UUID v4 生成
└── stores/
    ├── authStore.ts        任意サインインと同期状態
    └── workoutStore.ts     実行中のワークアウト
```

## 起動と実行

```bash
npm install
npm run web        # ブラウザ（E2Eもここに対して走る）
npm run ios
npm run android
```

## テスト

```bash
npm run typecheck
npm test           # Jest 91件
npm run test:e2e   # Playwright 84件（dev serverは自動起動）
npm run verify     # 上記3つを順に
```

書き方の注意は [../docs/TESTING.md](../docs/TESTING.md) にまとめてあります。
特にE2Eは、タブを切り替えても前の画面のDOMが残る点に注意してください。

## この実装に固有の事情

### AsyncStorage v3 のAPI

v2までの `multiRemove` は **`removeMany`** に変わっています。
`multiGet` / `multiSet` も `getMany` / `setMany` です。

### Alert.alert はWebで表示されない

削除などの確認ダイアログは、Webでは `confirm()` に落としています。
E2Eからも同じ導線で操作できるようにするためです。

```ts
if (Platform.OS === 'web') {
  if (typeof confirm === 'function' && !confirm(message)) return;
  void remove();
  return;
}
Alert.alert(/* … */);
```

### ピッカーはネイティブPickerを使わない

`@react-native-picker/picker` はWebでの挙動が読みにくいので、
頻度・アイコン・カラー・種目の選択は全てボタン/チップで実装しています。

### サマリーからホームへ戻るときは push しない

スタックは `[タブ, サマリー]` なので、`router.replace('/(tabs)')` すると
既存のタブ画面の上にもう1つタブ画面が積まれます（DOMに `home-screen` が2つできる）。
`router.canGoBack()` を見て `back()` します。

### グラフはViewの高さで描いている

`react-native-gifted-charts` と `react-native-calendars` は依存に残っていますが、
進捗画面では使っていません。3実装で見た目を揃えやすく、Webでも確実に描画されるためです。

## Supabase

`src/lib/supabase.ts` にURLとanonキーを直書きしています。
anonキーは公開前提の値で、行単位のアクセス制御はRLSが担います。

マイグレーションは `supabase/migrations/` にあり、**このディレクトリが3実装共通の正**です。
Flutter版・KMP版もこのスキーマに対して同期します。
