import 'scenarios.dart';

/// アプリ全体のシナリオをヘッドレスで実行する（`flutter test`）。
/// 同じシナリオを実機/シミュレータで走らせたい場合は
/// `flutter test integration_test` を使う。
void main() {
  registerScenarios();
}
