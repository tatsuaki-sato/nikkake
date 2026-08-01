import 'package:uuid/uuid.dart';
import 'local_store.dart';

/// ローカルの「テーブル」名。Supabase側のテーブル名と1:1で対応させてあるので、
/// 同期処理は名前をそのまま使ってpush/pullできる。
class Collections {
  static const exercises = 'exercises';
  static const routines = 'routines';
  static const routineExercises = 'routine_exercises';
  static const routineLogs = 'routine_logs';
  static const exerciseLogs = 'exercise_logs';

  /// 親→子の順。外部キー制約を壊さないためにこの順でpushする
  static const all = [exercises, routines, routineExercises, routineLogs, exerciseLogs];
}

class LocalMeta {
  final int schemaVersion;
  final bool seeded;

  /// 最後にSupabaseと同期できた時刻。pullの差分取得カーソルも兼ねる
  final DateTime? lastSyncedAt;

  /// 同期先アカウント。別アカウントでサインインしたらカーソルを捨てる
  final String? syncUserId;

  const LocalMeta({
    this.schemaVersion = LocalDb.currentSchemaVersion,
    this.seeded = false,
    this.lastSyncedAt,
    this.syncUserId,
  });

  factory LocalMeta.fromJson(Map<String, dynamic> json) => LocalMeta(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? LocalDb.currentSchemaVersion,
        seeded: json['seeded'] as bool? ?? false,
        lastSyncedAt:
            json['lastSyncedAt'] == null ? null : DateTime.parse(json['lastSyncedAt'] as String),
        syncUserId: json['syncUserId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'seeded': seeded,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'syncUserId': syncUserId,
      };

  LocalMeta copyWith({bool? seeded, DateTime? lastSyncedAt, String? syncUserId}) => LocalMeta(
        schemaVersion: schemaVersion,
        seeded: seeded ?? this.seeded,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        syncUserId: syncUserId ?? this.syncUserId,
      );
}

class UpsertResult {
  final int inserted;
  final int updated;
  final int skipped;

  const UpsertResult(this.inserted, this.updated, this.skipped);
}

/// JSONのMapを行として扱う汎用のローカルDB。
/// 型付きの読み書きは Repository が担当する。
class LocalDb {
  static const currentSchemaVersion = 1;
  static const _uuid = Uuid();

  final LocalStore store;

  LocalDb(this.store);

  static String newId() => _uuid.v4();
  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  LocalMeta getMeta() => LocalMeta.fromJson(store.readObject('meta', const LocalMeta().toJson()));

  Future<LocalMeta> setMeta({bool? seeded, DateTime? lastSyncedAt, String? syncUserId}) async {
    final next = getMeta().copyWith(
      seeded: seeded,
      lastSyncedAt: lastSyncedAt,
      syncUserId: syncUserId,
    );
    await store.writeObject('meta', next.toJson());
    return next;
  }

  /// 論理削除されていない行だけ
  List<Map<String, dynamic>> list(String collection) =>
      store.readCollection(collection).where((r) => r['deleted_at'] == null).toList();

  /// 論理削除済みも含む生データ。同期処理だけが使う
  List<Map<String, dynamic>> listRaw(String collection) => store.readCollection(collection);

  Map<String, dynamic>? find(String collection, String id) {
    for (final row in list(collection)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  List<Map<String, dynamic>> where(String collection, bool Function(Map<String, dynamic>) test) =>
      list(collection).where(test).toList();

  Future<Map<String, dynamic>> insert(String collection, Map<String, dynamic> values) async {
    final rows = [...store.readCollection(collection)];
    final timestamp = nowIso();

    final row = {
      ...values,
      'id': values['id'] ?? newId(),
      'created_at': values['created_at'] ?? timestamp,
      'updated_at': timestamp,
      'deleted_at': null,
    };

    rows.add(row);
    await store.writeCollection(collection, rows);
    return row;
  }

  Future<List<Map<String, dynamic>>> insertMany(
    String collection,
    List<Map<String, dynamic>> valuesList,
  ) async {
    if (valuesList.isEmpty) return const [];

    final rows = [...store.readCollection(collection)];
    final timestamp = nowIso();

    final created = valuesList
        .map((values) => {
              ...values,
              'id': values['id'] ?? newId(),
              'created_at': values['created_at'] ?? timestamp,
              'updated_at': timestamp,
              'deleted_at': null,
            })
        .toList();

    rows.addAll(created);
    await store.writeCollection(collection, rows);
    return created;
  }

  Future<Map<String, dynamic>?> update(
    String collection,
    String id,
    Map<String, dynamic> patch,
  ) async {
    final rows = [...store.readCollection(collection)];
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index < 0) return null;

    final updated = {...rows[index], ...patch, 'id': id, 'updated_at': nowIso()};
    rows[index] = updated;
    await store.writeCollection(collection, rows);
    return updated;
  }

  /// 論理削除。物理削除にすると「削除した」という事実が同期先に伝わらず、
  /// 他端末からpullし直すたびに復活してしまう。
  Future<bool> softDelete(String collection, String id) async {
    final rows = [...store.readCollection(collection)];
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index < 0) return false;

    final timestamp = nowIso();
    rows[index] = {...rows[index], 'deleted_at': timestamp, 'updated_at': timestamp};
    await store.writeCollection(collection, rows);
    return true;
  }

  Future<int> softDeleteWhere(
    String collection,
    bool Function(Map<String, dynamic>) test,
  ) async {
    final rows = [...store.readCollection(collection)];
    final timestamp = nowIso();
    var count = 0;

    for (var i = 0; i < rows.length; i++) {
      if (rows[i]['deleted_at'] != null || !test(rows[i])) continue;
      rows[i] = {...rows[i], 'deleted_at': timestamp, 'updated_at': timestamp};
      count++;
    }

    if (count > 0) await store.writeCollection(collection, rows);
    return count;
  }

  /// pull結果の取り込み。updated_atが新しい方を採用する (last-write-wins)
  Future<UpsertResult> upsertFromRemote(
    String collection,
    List<Map<String, dynamic>> remoteRows,
  ) async {
    final byId = {for (final r in store.readCollection(collection)) r['id'] as String: r};
    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    for (final remote in remoteRows) {
      final id = remote['id'] as String;
      final local = byId[id];

      if (local == null) {
        byId[id] = remote;
        inserted++;
        continue;
      }

      final remoteAt = DateTime.parse(remote['updated_at'] as String);
      final localAt = DateTime.parse(local['updated_at'] as String);

      if (remoteAt.isAfter(localAt)) {
        byId[id] = remote;
        updated++;
      } else {
        skipped++;
      }
    }

    await store.writeCollection(collection, byId.values.toList());
    return UpsertResult(inserted, updated, skipped);
  }

  /// 前回同期以降に変更された行（push対象）
  List<Map<String, dynamic>> changedSince(String collection, DateTime? since) {
    final rows = store.readCollection(collection);
    if (since == null) return rows;

    return rows
        .where((r) => DateTime.parse(r['updated_at'] as String).isAfter(since))
        .toList();
  }

  Future<void> reset() => store.clearAll();
}
