# 🐦 Nikkake Development Context (Flutter)

## プロジェクト概要
NikkakeアプリのFlutter（Dart）実装です。React Native版と完全な互換性（機能・デザイン）を持っています。

## 技術スタック
- **UI/Framework**: Flutter
- **State Management**: Provider
- **Routing**: go_router
- **Backend/Auth**: `supabase_flutter`
- **Testing**: `integration_test`, `mocktail`

## 環境構築と起動方法
1. 依存関係のインストール: `flutter pub get`
2. アプリの起動: `flutter run` (接続デバイスまたはシミュレータを選択)

## テスト運用方針
- `integration_test/` フォルダに React Native版のPlaywright相当のテストを実装しています。
- テスト実行: `flutter test integration_test`
- モックサーバー等を利用してSupabase通信をスタブ化するか、テスト用環境変数を利用します。

## デプロイとCI/CD
- `flutter build ipa` (iOS) および `flutter build appbundle` (Android) を使用します。
- CI/CDには Fastlane または GitHub Actions の導入が推奨されます。
