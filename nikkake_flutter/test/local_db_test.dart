import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/data/local_db.dart';
import 'helpers.dart';

Map<String, dynamic> newRoutine(String name) => {
      'user_id': null,
      'name': name,
      'description': null,
      'color': '#6C5CE7',
      'icon': '💪',
      'frequency_type': 'daily',
      'frequency_value': 1,
      'frequency_days': <int>[],
      'is_active': true,
      'sort_order': 0,
    };

void main() {
  late LocalDb db;

  setUp(() async {
    db = await createTestDb();
  });

  group('基本のCRUD', () {
    test('insert はIDとタイムスタンプを自動で埋める', () async {
      final row = await db.insert(Collections.routines, newRoutine('朝トレ'));

      expect(
        row['id'] as String,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
      expect(row['deleted_at'], isNull);
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
    });

    test('明示的に渡したIDは尊重される（プリセットの固定IDのため）', () async {
      final row = await db.insert(Collections.routines, {...newRoutine('固定'), 'id': 'fixed-id'});
      expect(row['id'], 'fixed-id');
    });

    test('find / where で絞り込める', () async {
      await db.insertMany(Collections.routines, [newRoutine('A'), newRoutine('B')]);
      final all = db.list(Collections.routines);

      expect(all.length, 2);
      expect(db.find(Collections.routines, all.first['id'] as String), isNotNull);
      expect(db.where(Collections.routines, (r) => r['name'] == 'B').length, 1);
    });

    test('update は updated_at を進める', () async {
      final row = await db.insert(Collections.routines, newRoutine('元の名前'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final updated = await db.update(Collections.routines, row['id'] as String, {'name': '新しい名前'});

      expect(updated?['name'], '新しい名前');
      expect(
        DateTime.parse(updated!['updated_at'] as String)
            .isBefore(DateTime.parse(row['updated_at'] as String)),
        isFalse,
      );
    });

    test('存在しないIDのupdateはnullを返す', () async {
      expect(await db.update(Collections.routines, 'missing', {'name': 'x'}), isNull);
    });
  });

  group('論理削除', () {
    test('softDelete した行は list から消えるが、生データには残る', () async {
      final row = await db.insert(Collections.routines, newRoutine('消す'));

      expect(await db.softDelete(Collections.routines, row['id'] as String), isTrue);
      expect(db.list(Collections.routines), isEmpty);

      // 削除された事実が同期先に伝わる必要があるので、行自体は残す
      final raw = db.listRaw(Collections.routines);
      expect(raw.length, 1);
      expect(raw.first['deleted_at'], isNotNull);
    });

    test('softDeleteWhere は条件に合う行だけ消し、件数を返す', () async {
      await db.insertMany(
        Collections.routines,
        [newRoutine('残す'), newRoutine('消す'), newRoutine('消す')],
      );

      final count = await db.softDeleteWhere(Collections.routines, (r) => r['name'] == '消す');

      expect(count, 2);
      expect(db.list(Collections.routines).length, 1);
    });

    test('削除済みの行を再度softDeleteしても二重に数えない', () async {
      await db.insert(Collections.routines, newRoutine('消す'));
      await db.softDeleteWhere(Collections.routines, (_) => true);

      expect(await db.softDeleteWhere(Collections.routines, (_) => true), 0);
    });
  });

  group('メタ情報', () {
    test('初期値を返し、部分更新できる', () async {
      final meta = db.getMeta();
      expect(meta.seeded, isFalse);

      await db.setMeta(seeded: true);
      final updated = db.getMeta();

      expect(updated.seeded, isTrue);
      expect(updated.schemaVersion, meta.schemaVersion);
    });
  });
}
