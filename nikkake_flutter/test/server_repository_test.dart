import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nikkake_flutter/data/graphql_client.dart';
import 'package:nikkake_flutter/data/local_db.dart';
import 'package:nikkake_flutter/data/nikkake_repository.dart';
import 'package:nikkake_flutter/data/repository.dart';
import 'package:nikkake_flutter/data/server_repository.dart';
import 'package:nikkake_flutter/models/models.dart';

import 'helpers.dart';

/// サーバ実装の検証。
///
/// 実サーバは立てず、GraphQL の応答だけを差し替える。
/// ここで確かめたいのは「サーバが返した形をそのまま画面へ渡せているか」と
/// 「圏外のときに記録を失わないか」で、Rails 側の正しさは RSpec が見ている。
void main() {
  late LocalDb db;
  late Repository local;
  late _FakeTransport transport;
  late ServerRepository server;

  setUp(() async {
    db = await createTestDb();
    local = Repository(db);
    await local.seedIfNeeded();

    transport = _FakeTransport();
    server = ServerRepository(
      db: db,
      local: local,
      endpoint: 'http://example.test/graphql',
      client: GraphQLClient(
        endpoint: 'http://example.test/graphql',
        readToken: () => db.getMeta().apiToken,
        httpClient: transport,
      ),
    );
  });

  group('遅延登録', () {
    test('匿名アカウントのトークンを保存する', () async {
      transport.reply('createAnonymousAccount', {
        'createAnonymousAccount': {'token': 'tok_abc', 'userErrors': []},
      });

      expect(await server.ensureSession(), 'tok_abc');
      expect(db.getMeta().apiToken, 'tok_abc');
    });

    test('圏外でも例外を投げない。次の起動で再試行できる', () async {
      transport.failWith(const NetworkFailure('圏外'));

      expect(await server.ensureSession(), isNull);
      expect(db.getMeta().apiToken, isNull);
    });

    test('端末側でシードするので、サーバには初期ルーティンを作らせない', () async {
      transport.reply('createAnonymousAccount', {
        'createAnonymousAccount': {'token': 'tok_abc', 'userErrors': []},
      });

      server.suppressStarterRoutine();
      await server.ensureSession();

      expect(transport.lastVariables['withStarterRoutine'], isFalse);
    });

    test('預け入れは一度きり。二度目は送らない', () async {
      transport.reply('importSnapshot', {
        'importSnapshot': {'imported': {}, 'userErrors': []},
      });

      expect(await server.importSnapshot(), isTrue);
      expect(await server.importSnapshot(), isFalse);

      // 切り替え直前の書き込みを拾うときだけ、明示的に送り直せる
      expect(await server.importSnapshot(force: true), isTrue);
    });

    test('プリセット種目は送らない。サーバが持っているものを上書きしてしまう', () async {
      transport.reply('importSnapshot', {
        'importSnapshot': {'imported': {}, 'userErrors': []},
      });

      await server.importSnapshot();

      final sent = transport.lastVariables['exercises'] as List;
      expect(sent, isEmpty);
      expect((transport.lastVariables['routines'] as List).length, 1);
    });
  });

  group('参照', () {
    test('ホームの区分をサーバの応答どおりに渡す', () async {
      transport.reply('Home', {
        'home': {
          'today': '2026-08-02',
          'streak': {'current': 3, 'longest': 5, 'lastCompletedDate': '2026-08-02'},
          'due': [_todayRoutine(name: '朝トレ', isDueToday: true, label: '毎日')],
          'notScheduled': [],
          'completed': [_todayRoutine(name: '夜トレ', isCompleted: true, label: '3日ごと')],
        },
      });

      final home = await server.getHome();

      expect(home.today, '2026-08-02');
      expect(home.streak.current, 3);
      expect(home.due.single.routine.name, '朝トレ');
      // 頻度の文言はサーバが返す。手元で組み立てない
      expect(home.due.single.frequencyLabel, '毎日');
      expect(home.completed.single.isCompleted, isTrue);
      expect(home.total, 2);
    });

    test('「今日」は端末が決めて送る', () async {
      transport.reply('Home', {
        'home': {
          'today': '2026-03-15',
          'streak': {'current': 0, 'longest': 0, 'lastCompletedDate': null},
          'due': [],
          'notScheduled': [],
          'completed': [],
        },
      });

      await server.getHome(DateTime(2026, 3, 15, 8));

      expect(transport.lastVariables['today'], '2026-03-15');
      expect(transport.lastVariables['timeZone'], isNotEmpty);
    });

    test('前回の記録の文言はサーバのものをそのまま出す', () async {
      transport.reply('WorkoutSession', {
        'workoutSession': {
          'routine': _routine(name: 'テスト'),
          'exercises': [
            {
              'routineExerciseId': 're1',
              'exercise': _exercise(),
              'targetSets': 3,
              'targetReps': 10,
              'targetWeight': 50,
              'targetDurationSec': null,
              'restSec': 90,
              'previousLabel': '50×10 / 50×9',
              'previousSets': [
                {'setNumber': 1, 'reps': 10, 'weight': 50, 'durationSec': null},
                {'setNumber': 2, 'reps': 9, 'weight': 50, 'durationSec': null},
              ],
            },
          ],
        },
      });

      final session = (await server.getWorkoutSession('r1'))!;

      expect(session.exercises.single.previousLabel, '50×10 / 50×9');
      expect(session.exercises.single.previousSets.length, 2);
      expect(session.exercises.single.restSec, 90);
    });
  });

  group('記録', () {
    final exercises = [
      const SaveWorkoutExercise(
        routineExerciseId: 're1',
        exerciseId: 'e1',
        sets: [
          WorkoutSet(setNumber: 1, reps: 10, weight: 50, completed: true),
          WorkoutSet(setNumber: 2, reps: 10, weight: 50, completed: false),
        ],
      ),
    ];

    test('サーバが返したサマリーをそのまま使う', () async {
      transport.reply('RecordWorkout', {
        'recordWorkout': {
          'summary': {
            'routineLogId': 'log1',
            'routineName': 'テスト',
            'durationSec': 300,
            'completedSets': 1,
            'totalSets': 2,
            'totalVolume': 500,
            'status': 'PARTIAL',
          },
          'streak': {'current': 1, 'longest': 1, 'lastCompletedDate': '2026-08-02'},
          'userErrors': [],
        },
      });

      final summary = await server.saveWorkout(
        routineId: 'r1',
        startedAt: DateTime(2026, 8, 2, 7),
        durationSec: 300,
        exercises: exercises,
      );

      expect(summary.status, LogStatus.partial);
      expect(summary.completedSets, 1);
      // 完了していないセットは送らない
      expect((transport.lastVariables['sets'] as List).length, 1);
      // 総セット数はサーバが status を判定するのに要る
      expect(transport.lastVariables['totalSets'], 2);
      expect(transport.lastVariables['logDate'], '2026-08-02');
    });

    test('圏外ならキューに積み、画面には暫定のサマリーを返す', () async {
      transport.failWith(const NetworkFailure('圏外'));

      final summary = await server.saveWorkout(
        routineId: 'r1',
        startedAt: DateTime(2026, 8, 2, 7),
        durationSec: 300,
        exercises: exercises,
      );

      // 記録は失われない
      expect(server.queue.pending().length, 1);
      expect(await server.pendingCount(), 1);

      // サーバと同じ基準で判定した結果が出る
      expect(summary.status, LogStatus.partial);
      expect(summary.completedSets, 1);
      expect(summary.totalVolume, 500);
    });

    test('復帰すると溜まった記録が送られ、キューが空になる', () async {
      transport.failWith(const NetworkFailure('圏外'));
      await server.saveWorkout(
        routineId: 'r1',
        startedAt: DateTime(2026, 8, 2, 7),
        durationSec: 300,
        exercises: exercises,
      );

      transport.recover();
      transport.reply('RecordWorkout', {
        'recordWorkout': {'summary': null, 'streak': null, 'userErrors': []},
      });

      expect(await server.flushQueue(), 1);
      expect(server.queue.pending(), isEmpty);
    });

    test('再送しても同じIDなので二重登録されない', () async {
      transport.failWith(const NetworkFailure('圏外'));
      await server.saveWorkout(
        routineId: 'r1',
        startedAt: DateTime(2026, 8, 2, 7),
        durationSec: 300,
        exercises: exercises,
      );

      final queued = server.queue.pending().single;
      expect(queued.payload['id'], queued.payload['clientMutationId']);

      // 同じIDを積み直しても増えない
      await server.queue.enqueue(queued.id, queued.payload);
      expect(server.queue.pending().length, 1);
    });
  });

  group('更新', () {
    test('userErrors はそのまま画面に出せる例外になる', () async {
      transport.reply('CreateRoutine', {
        'createRoutine': {
          'routine': null,
          'userErrors': [
            {'message': '名前を入力してください', 'code': 'VALIDATION', 'path': ['name']},
          ],
        },
      });

      expect(
        () => server.createRoutine(
          const RoutineInput(name: '', icon: '💪', color: '#6C5CE7'),
        ),
        throwsA(isA<PermanentFailure>()
            .having((e) => e.message, 'message', '名前を入力してください')),
      );
    });
  });
}

// ==============================
// 応答を差し替えるだけの薄いテスト用クライアント
// ==============================

class _FakeTransport extends http.BaseClient {
  final Map<String, Map<String, dynamic>> _replies = {};
  Object? _failure;

  Map<String, dynamic> lastVariables = const {};

  void reply(String operationHint, Map<String, dynamic> data) {
    _replies[operationHint] = data;
  }

  void failWith(Object error) => _failure = error;
  void recover() => _failure = null;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_failure != null) {
      // GraphQLClient が NetworkFailure に包み直す
      throw _failure!;
    }

    final body = jsonDecode(await (request as http.Request).finalize().bytesToString())
        as Map<String, dynamic>;
    final query = body['query'] as String;
    lastVariables = (body['variables'] as Map).cast<String, dynamic>();

    final match = _replies.entries.where((e) => query.contains(e.key)).firstOrNull;
    final data = match?.value ?? const <String, dynamic>{};

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'data': data}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Map<String, dynamic> _exercise() => {
      'id': 'e1',
      'name': '腕立て伏せ',
      'category': 'STRENGTH',
      'icon': '💪',
      'isPreset': true,
    };

Map<String, dynamic> _routine({required String name}) => {
      'id': 'r1',
      'name': name,
      'description': null,
      'color': '#6C5CE7',
      'icon': '💪',
      'frequencyType': 'DAILY',
      'frequencyValue': 1,
      'frequencyDays': <int>[],
      'isActive': true,
      'sortOrder': 0,
      'lockVersion': 2,
      'routineExercises': [
        {
          'id': 're1',
          'sortOrder': 0,
          'targetSets': 3,
          'targetReps': 10,
          'targetWeight': null,
          'targetDurationSec': null,
          'restSec': 60,
          'exercise': _exercise(),
        },
      ],
    };

Map<String, dynamic> _todayRoutine({
  required String name,
  bool isDueToday = false,
  bool isCompleted = false,
  String label = '毎日',
}) =>
    {
      'routine': _routine(name: name),
      'isDueToday': isDueToday,
      'isCompleted': isCompleted,
      'frequencyLabel': label,
    };
