# 🚀 Nikkake Development Context (KMP / Compose)

## プロジェクト概要
Nikkakeアプリの Kotlin Multiplatform (KMP) 実装です。UIは Compose Multiplatform を用いてiOS/Android間で共通化されています。

## 技術スタック
- **UI/Framework**: Compose Multiplatform
- **Routing**: Voyager
- **Backend/Auth**: `supabase-kt` (PostgreSQL/Auth)
- **Testing**: Compose UI Test

## 環境構築と起動方法
1. Android Studio を使用するか、ターミナルで `./gradlew` を使用します。
2. Android起動: `./gradlew :composeApp:installDebug`
3. iOS起動: XcodeまたはFleetからiOSシミュレータを選択して実行します。

## テスト運用方針
- `shared/src/commonTest/` 以下に Compose UI Test を用いた画面テストが実装されています。
- テスト実行: `./gradlew :shared:allTests` 
- プラットフォーム固有の描画差異を検知するためのスクリーンショットテストの導入も検討されます。

## デプロイとCI/CD
- Android: `./gradlew :composeApp:bundleRelease`
- iOS: KMPの `embedAndSignAppleFrameworkForXcode` タスクを連携し、Fastlane/Xcode経由でアーカイブします。
