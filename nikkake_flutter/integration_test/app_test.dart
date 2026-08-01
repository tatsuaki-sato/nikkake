import 'package:integration_test/integration_test.dart';
import '../test/scenarios.dart';

/// 実機/シミュレータ上で同じシナリオを実行する。
///
///   flutter test integration_test
///
/// シナリオ本体は test/scenarios.dart に置いてあり、
/// ヘッドレス版(`flutter test`)とまったく同じ手順を共有している。
/// 実機でしか出ない描画やプラットフォームチャネルの問題を検知するのがこちらの役目。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerScenarios();
}
