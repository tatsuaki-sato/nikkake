import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/graphql_client.dart';
import '../models/models.dart';

/// アカウントの状態。
///
/// サインインは「任意」で、意味は**端末を変えてもデータが残ること**だけです。
/// サインインしていなくても全機能が使えるので、これが画面をブロックすることはありません。
///
/// 匿名でも記録はサーバに預けられています。違いは取り戻す手段だけで、
/// 匿名だとこの端末のトークンを失った時点で辿り着けなくなります。
///
/// **メール登録でデータは1件も移動しません。** 匿名アカウントに
/// メールとパスワードを足すだけで `user.id` が変わらないためです。
/// 移行前にあった claimLocalRows のような引き取り処理は不要になりました。
class AuthController extends ChangeNotifier {
  AuthController(this.backend);

  final BackendSwitch backend;

  Viewer? _viewer;
  int _pending = 0;
  String? _lastError;
  bool _initialized = false;

  Viewer? get viewer => _viewer;
  int get pendingCount => _pending;
  String? get lastError => _lastError;
  bool get initialized => _initialized;

  StorageMode get mode =>
      (_viewer == null || _viewer!.isAnonymous) ? StorageMode.local : StorageMode.cloud;

  Future<void> initialize() async {
    await refresh();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _pending = await backend.pendingCount();

    final api = backend.server;
    // サーバに登録できていないあいだは、そもそも聞きに行く相手がいない
    if (api == null || !backend.isServerReady) {
      _viewer = null;
      notifyListeners();
      return;
    }

    try {
      _viewer = await api.viewer();
    } catch (_) {
      // 圏外でも画面は出す。次に開いたときに取り直す
      _viewer = null;
    }
    notifyListeners();
  }

  /// 既にあるアカウントへ切り替える。
  /// この端末の匿名データを取り込むかは merge で決める（既定は取り込まない）。
  Future<String?> signIn(String email, String password) async {
    final api = backend.server;
    if (api == null) return 'この端末はサーバに接続していません';

    try {
      _viewer = await api.linkExistingAccount(email: email, password: password);
      notifyListeners();
      return null;
    } on PermanentFailure catch (e) {
      // サーバは userErrors.message にそのまま画面へ出せる日本語を入れて返す
      return e.message;
    } catch (_) {
      return 'サーバに接続できませんでした。電波の良いところで試してください。';
    }
  }

  /// いま使っている匿名アカウントにメールとパスワードを足す。
  /// 新しいアカウントを作るのではないので、記録はそのまま残る。
  Future<String?> signUp(String email, String password, {String? displayName}) async {
    final api = backend.server;
    if (api == null) return 'この端末はサーバに接続していません';

    try {
      _viewer = await api.attachEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      notifyListeners();
      return null;
    } on PermanentFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'サーバに接続できませんでした。電波の良いところで試してください。';
    }
  }

  /// サインアウトしても記録は消えません。
  /// この端末から見えなくなるだけで、同じアカウントで入り直せば戻ります。
  Future<void> signOut() async {
    final api = backend.server;
    try {
      await api?.signOut();
    } finally {
      _viewer = null;
      notifyListeners();
    }
  }

  /// 送信待ちの記録を送る
  Future<void> flushNow() async {
    final api = backend.server;
    if (api == null) return;

    try {
      await api.flushQueue();
      _lastError = null;
    } catch (e) {
      _lastError = '$e';
    }
    _pending = await backend.pendingCount();
    notifyListeners();
  }
}
