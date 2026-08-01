import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'local_db.dart';

/// Supabaseとの同期。
///
/// 方針:
///  - ローカルが常に真実の源。同期はあくまで「バックアップと他端末への複製」
///  - 衝突は updated_at の新しい方を採用する (last-write-wins)
///  - 失敗しても画面は動き続ける。次回の同期でリトライされる
///
/// サインインしていない場合、この層は一切呼ばれない。
class SyncException implements Exception {
  final String message;
  final String? collection;

  SyncException(this.message, [this.collection]);

  @override
  String toString() => 'SyncException($collection): $message';
}

class SyncResult {
  final int pushed;
  final int pulled;
  final DateTime syncedAt;

  const SyncResult({required this.pushed, required this.pulled, required this.syncedAt});
}

class SyncService {
  /// ユーザーに紐づくテーブル。pull時に user_id で絞り込む
  static const userScoped = [Collections.routines, Collections.routineLogs];

  final LocalDb db;
  final SupabaseClient client;

  SyncService(this.db, this.client);

  /// サインイン直後に一度だけ実行する。
  /// それまで user_id = null で作られていたローカルのレコードを、
  /// このアカウントのものとして引き取る。
  Future<int> claimLocalRows(String userId) async {
    var claimed = 0;

    for (final collection in userScoped) {
      final rows = [...db.listRaw(collection)];
      var changed = false;

      for (var i = 0; i < rows.length; i++) {
        if (rows[i]['user_id'] == userId) continue;
        rows[i] = {...rows[i], 'user_id': userId, 'updated_at': LocalDb.nowIso()};
        changed = true;
        claimed++;
      }

      if (changed) await db.store.writeCollection(collection, rows);
    }

    return claimed;
  }

  Future<int> _push(String collection, DateTime? since) async {
    var rows = db.changedSince(collection, since);

    // プリセット種目はサーバ側にも同じIDで存在する共有マスタなので送らない
    if (collection == Collections.exercises) {
      rows = rows.where((r) => r['is_preset'] != true).toList();
    }
    if (rows.isEmpty) return 0;

    try {
      await client.from(collection).upsert(rows, onConflict: 'id');
    } on PostgrestException catch (e) {
      throw SyncException(e.message, collection);
    }
    return rows.length;
  }

  Future<int> _pull(String collection, DateTime? since, String userId) async {
    try {
      var query = client.from(collection).select();
      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }
      if (userScoped.contains(collection)) {
        query = query.eq('user_id', userId);
      }

      final data = await query;
      final rows = (data as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return 0;

      final result = await db.upsertFromRemote(collection, rows);
      return result.inserted + result.updated;
    } on PostgrestException catch (e) {
      throw SyncException(e.message, collection);
    }
  }

  /// 双方向同期を1回実行する。
  ///
  /// pushを先にやるのは、同じレコードを両方が持っていた場合に
  /// サーバ側の updated_at が確定してからpullしたいため。
  Future<SyncResult> runSync(String userId) async {
    final meta = db.getMeta();

    // 別アカウントでサインインし直した場合は差分カーソルを捨てて全件取り直す
    final since = meta.syncUserId == userId ? meta.lastSyncedAt : null;

    // 処理中に増えた変更を取りこぼさないよう、完了時刻ではなく開始時刻をカーソルにする
    final startedAt = DateTime.now().toUtc();

    var pushed = 0;
    for (final collection in Collections.all) {
      pushed += await _push(collection, since);
    }

    var pulled = 0;
    for (final collection in Collections.all) {
      pulled += await _pull(collection, since, userId);
    }

    await db.setMeta(lastSyncedAt: startedAt, syncUserId: userId);
    return SyncResult(pushed: pushed, pulled: pulled, syncedAt: startedAt);
  }

  /// 例外を投げない版。UIから呼ぶときはこちらを使い、失敗しても操作をブロックしない。
  Future<SyncState> trySync(String userId) async {
    try {
      final result = await runSync(userId);
      return SyncState(status: SyncStatus.idle, lastSyncedAt: result.syncedAt);
    } catch (error) {
      final message = error is SyncException ? error.message : error.toString();

      // ネットワーク由来かどうかで表示を出し分ける
      final isOffline = RegExp(r'network|socket|timeout|failed host lookup|connection', caseSensitive: false)
          .hasMatch(message);

      return SyncState(
        status: isOffline ? SyncStatus.offline : SyncStatus.error,
        lastSyncedAt: db.getMeta().lastSyncedAt,
        lastError: message,
      );
    }
  }

  /// 設定画面に出す「未送信の変更」の件数
  int getPendingCount() {
    final since = db.getMeta().lastSyncedAt;
    var count = 0;

    for (final collection in Collections.all) {
      final rows = db.changedSince(collection, since);
      count += collection == Collections.exercises
          ? rows.where((r) => r['is_preset'] != true).length
          : rows.length;
    }
    return count;
  }
}
