import 'package:flutter_timezone/flutter_timezone.dart';

/// 端末のタイムゾーンを IANA 名（"Asia/Tokyo"）で返す。
///
/// Dart 標準の `DateTime.now().timeZoneName` は "JST" のような略称しか返さない。
/// サーバはこの値を `ActiveSupport::TimeZone` で解決するので、略称だと
/// 解決できず既定値へ倒れてしまう（実際に users.time_zone に 'JST' が入っていた）。
///
/// なお、サーバはこの値を日付の判定には使わない。
/// 「今日」は必ずクライアントが決めて送る（docs/ARCHITECTURE.md 原則1）。
/// ここで送るのは、事故が起きたときに検証・救済するための記録用。
class DeviceTimeZone {
  static String _cached = 'Asia/Tokyo';

  /// 起動時に1回だけ解決してキャッシュする。
  /// プラットフォームチャネル越しなので、記録のたびに呼ぶと遅い。
  static Future<void> resolve() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      if (name.isNotEmpty) _cached = name;
    } catch (_) {
      // 取れなくてもアプリは動く。既定のまま送る
    }
  }

  static String get name => _cached;

  /// テスト用
  static void overrideForTest(String value) => _cached = value;
}
