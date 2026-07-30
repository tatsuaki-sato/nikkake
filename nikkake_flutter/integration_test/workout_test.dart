import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:nikkake_flutter/main.dart';
import 'package:nikkake_flutter/services/services.dart';
import 'package:nikkake_flutter/providers/providers.dart';
import 'package:nikkake_flutter/models/models.dart';

class MockWorkoutApiService implements ApiService {
  @override
  Future<User?> getSession() async => User(id: 'test', email: 'test@example.com');
  @override
  Future<User> login(String e, String p) async => User(id: 'test', email: e);
  @override
  Future<User> register(String e, String p) async => User(id: 'test', email: e);
  
  @override
  Future<List<Routine>> fetchRoutines() async {
    return [
      Routine(id: '1', name: '今日のテストルーティン', icon: '🔥'),
    ];
  }
  @override
  Future<Routine> createRoutine(Map<String, dynamic> data) async => Routine(id: '2', name: 'new', icon: '🔥');
  @override
  Future<List<RoutineLog>> fetchRoutineLogs() async {
    return [
      RoutineLog(logDate: '2026-07-11', status: 'completed'),
    ];
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ホームからワークアウトを開始できるか', (WidgetTester tester) async {
    final mockApi = MockWorkoutApiService();
    final auth = AuthProvider(mockApi);
    auth.setUser(User(id: 'test', email: 'test'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => RoutineProvider(mockApi)),
        ],
        child: const NikkakeApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('今日のルーティン'), findsOneWidget);
    expect(find.text('今日のテストルーティン'), findsOneWidget);
    
    await tester.tap(find.text('開始する'));
    await tester.pumpAndSettle();
    
    expect(find.text('ワークアウト'), findsOneWidget);
  });

  testWidgets('進捗画面でカレンダーとチャートが表示されるか', (WidgetTester tester) async {
    final mockApi = MockWorkoutApiService();
    final auth = AuthProvider(mockApi);
    auth.setUser(User(id: 'test', email: 'test'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => RoutineProvider(mockApi)),
        ],
        child: const NikkakeApp(),
      ),
    );

    await tester.pumpAndSettle();
    
    // Switch to progress tab
    await tester.tap(find.text('進捗状況').last); // The bottom nav bar item
    await tester.pumpAndSettle();
    
    expect(find.text('完了したワークアウト'), findsOneWidget);
    expect(find.text('1 回'), findsOneWidget);
    expect(find.text('ボリューム推移（モック）'), findsOneWidget);
  });
}
