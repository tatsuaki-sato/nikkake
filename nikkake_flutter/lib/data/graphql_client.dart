import 'dart:convert';

import 'package:http/http.dart' as http;

import 'time_zone.dart';

/// GraphQL の呼び出し口。
///
/// 専用クライアントは入れていない。エンドポイントは1本で、
/// 正規化キャッシュも購読も使わないので、素のPOSTで足りる。
/// 依存が1つ減るぶん、Dartのバージョン追従で壊れる余地も減る。

/// 圏外のときに保存系の画面へ出す文言。
///
/// 端末の接続状態フラグでは判定しない。Wi-Fi に繋がっていてもサーバへ届かないことがあり、
/// 逆に「圏外」でも届くことがある。実際に送ってみた結果で判断する。
const offlineSaveMessage = 'オフラインのため保存できません。電波のあるところで試してください。';

/// ネットワークが原因の失敗。再送する価値がある
class NetworkFailure implements Exception {
  const NetworkFailure(this.message);
  final String message;

  @override
  String toString() => 'NetworkFailure: $message';
}

/// サーバが受け付けなかった。再送しても同じなので dead キューへ送る
class PermanentFailure implements Exception {
  const PermanentFailure(this.message);
  final String message;

  @override
  String toString() => 'PermanentFailure: $message';
}

class GraphQLClient {
  GraphQLClient({
    required this.endpoint,
    required this.readToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String endpoint;
  final String? Function() readToken;
  final http.Client _http;

  Future<Map<String, dynamic>> request(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final token = readToken();

    http.Response response;
    try {
      response = await _http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          // サーバは「今日」を計算しないが、ログと救済のためにTZは受け取る
          'X-Nikkake-Timezone': DeviceTimeZone.name,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      );
    } catch (e) {
      throw NetworkFailure('$e');
    }

    if (response.statusCode >= 500) {
      throw NetworkFailure('サーバエラー (${response.statusCode})');
    }
    if (response.statusCode >= 400) {
      throw PermanentFailure('リクエストが拒否されました (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    // GraphQL は 200 で errors を返す。ここを見ないと失敗が素通りする
    final errors = body['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final message = (errors.first as Map<String, dynamic>)['message'] as String?;
      throw PermanentFailure(message ?? 'GraphQL エラー');
    }

    return (body['data'] as Map<String, dynamic>?) ?? const {};
  }

  void close() => _http.close();
}
