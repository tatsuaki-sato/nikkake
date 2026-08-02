import 'dart:convert';

import 'graphql_client.dart';
import 'local_db.dart';

/// オフライン記録のキュー。
///
/// 記録だけがオフライン可（ルーティンの作成・編集はオンライン必須）。
/// id は clientMutationId としてそのままサーバへ送るので、
/// 再送しても mutation_receipts とクライアント生成UUIDの主キー衝突で吸収される。
class QueuedOp {
  const QueuedOp({
    required this.id,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
    this.lastError,
  });

  final String id;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime nextAttemptAt;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt.toIso8601String(),
        'lastError': lastError,
      };

  static QueuedOp fromJson(Map<String, dynamic> json) => QueuedOp(
        id: json['id'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        attempts: json['attempts'] as int? ?? 0,
        nextAttemptAt:
            DateTime.tryParse(json['nextAttemptAt'] as String? ?? '') ?? DateTime.now(),
        lastError: json['lastError'] as String?,
      );
}

class OfflineQueue {
  OfflineQueue(this.db);

  final LocalDb db;

  static const _maxBackoff = Duration(minutes: 5);

  List<QueuedOp> _read({required bool isDead}) {
    final meta = db.getMeta();
    final raw = isDead ? meta.offlineQueueDead : meta.offlineQueue;
    if (raw == null || raw.isEmpty) return [];

    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(QueuedOp.fromJson)
          .toList();
    } catch (_) {
      // 壊れたJSONで記録できなくなるのが最悪なので、握りつぶして空で復旧する
      return [];
    }
  }

  Future<void> _write({required bool isDead, required List<QueuedOp> ops}) {
    final encoded = jsonEncode(ops.map((o) => o.toJson()).toList());
    return isDead
        ? db.setMeta(offlineQueueDead: encoded)
        : db.setMeta(offlineQueue: encoded);
  }

  List<QueuedOp> pending() => _read(isDead: false);

  /// 送信できなかったもの。設定画面に出して手動対応させる
  List<QueuedOp> dead() => _read(isDead: true);

  Future<void> enqueue(String id, Map<String, dynamic> payload) async {
    final ops = pending();
    if (ops.any((o) => o.id == id)) return;

    ops.add(QueuedOp(
      id: id,
      payload: payload,
      attempts: 0,
      nextAttemptAt: DateTime.now(),
    ));
    await _write(isDead: false, ops: ops);
  }

  /// 直列に送る。失敗したら以降は次回に回して順序を守る。
  /// オフライン記録は少数なので並列化する必要がない。
  Future<int> flush(Future<void> Function(QueuedOp) send) async {
    var sent = 0;

    for (final op in pending()) {
      if (op.nextAttemptAt.isAfter(DateTime.now())) continue;

      try {
        await send(op);
        await _remove(op.id);
        sent++;
      } on PermanentFailure catch (e) {
        await _moveToDead(op, e.message);
        break;
      } catch (e) {
        await _backoff(op, '$e');
        break;
      }
    }

    return sent;
  }

  Future<void> _remove(String id) =>
      _write(isDead: false, ops: pending().where((o) => o.id != id).toList());

  Future<void> _moveToDead(QueuedOp op, String message) async {
    await _remove(op.id);
    await _write(isDead: true, ops: [
      ...dead(),
      QueuedOp(
        id: op.id,
        payload: op.payload,
        attempts: op.attempts,
        nextAttemptAt: op.nextAttemptAt,
        lastError: message,
      ),
    ]);
  }

  Future<void> _backoff(QueuedOp op, String message) async {
    final attempts = op.attempts + 1;
    var delay = Duration(seconds: 1 << op.attempts);
    if (delay > _maxBackoff) delay = _maxBackoff;

    await _write(
      isDead: false,
      ops: pending()
          .map((o) => o.id == op.id
              ? QueuedOp(
                  id: o.id,
                  payload: o.payload,
                  attempts: attempts,
                  nextAttemptAt: DateTime.now().add(delay),
                  lastError: message,
                )
              : o)
          .toList(),
    );
  }
}
