import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/sync_service.dart';
import '../models/models.dart';

/// 認証は「任意」。
///
/// このアプリはサインインしなくても全機能が使える。
/// サインインの意味は「端末を変えてもデータが残る」ことだけなので、
/// このコントローラが未サインインでも画面は一切ブロックしない。
class AuthController extends ChangeNotifier {
  final SyncService syncService;
  final GoTrueClient auth;

  AuthController({required this.syncService, required this.auth});

  User? _user;
  SyncState _sync = const SyncState();
  bool _initialized = false;

  User? get user => _user;
  SyncState get sync => _sync;
  bool get initialized => _initialized;
  StorageMode get mode => _user == null ? StorageMode.local : StorageMode.cloud;

  Future<void> initialize() async {
    _sync = SyncState(lastSyncedAt: syncService.db.getMeta().lastSyncedAt);
    _user = auth.currentUser;
    _initialized = true;
    notifyListeners();

    auth.onAuthStateChange.listen((event) {
      _user = event.session?.user;
      notifyListeners();
    });

    if (_user != null) {
      await syncNow();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final response = await auth.signInWithPassword(email: email, password: password);
      _user = response.user;
      notifyListeners();
      await syncNow();
      return null;
    } on AuthException catch (e) {
      return e.message == 'Invalid login credentials' ? 'メールアドレスまたはパスワードが違います' : e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password, {String? displayName}) async {
    try {
      final response = await auth.signUp(
        email: email,
        password: password,
        data: displayName == null ? null : {'display_name': displayName},
      );

      // メール確認が必要な設定の場合、この時点ではセッションが無い
      if (response.session != null) {
        _user = response.user;
        notifyListeners();
        await syncNow();
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// サインアウトしてもローカルのデータは消さない。
  /// 「バックアップをやめる」だけであって、記録を捨てる操作ではないため。
  Future<void> signOut() async {
    await auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    final current = _user;
    if (current == null) return;

    _sync = SyncState(status: SyncStatus.syncing, lastSyncedAt: _sync.lastSyncedAt);
    notifyListeners();

    // サインイン前に作ったローカルのレコードをこのアカウントのものにする
    await syncService.claimLocalRows(current.id);

    _sync = await syncService.trySync(current.id);
    notifyListeners();
  }

  int get pendingCount => syncService.getPendingCount();
}
