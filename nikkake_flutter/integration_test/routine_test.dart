import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:nikkake_flutter/main.dart';
import 'package:nikkake_flutter/services/services.dart';
import 'package:nikkake_flutter/providers/providers.dart';
import 'package:nikkake_flutter/models/models.dart';

class MockRoutineApiService implements ApiService {
  @override
  Future<User?> getSession() async => User(id: 'test', email: 'test@example.com');
  @override
  Future<User> login(String e, String p) async => User(id: 'test', email: e);
  @override
  Future<User> register(String e, String p) async => User(id: 'test', email: e);
  
  @override
  Future<List<Routine>> fetchRoutines() async {
    return [
      Routine(id: '1', name: '既存のルーティン', icon: '🏋️', color: '#ff0000', frequencyType: 'daily', frequencyValue: 1, isActive: true),
    ];
  }
  @override
  Future<Routine> createRoutine(Map<String, dynamic> data) async => Routine(id: '2', name: data['name'] ?? '', icon: '🔥');
  @override
  Future<List<RoutineLog>> fetchRoutineLogs() async => [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ルーティン一覧から新規作成画面を開き、必須入力チェックを確認する', (WidgetTester tester) async {
    final mockApi = MockRoutineApiService();
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
    
    expect(find.text('既存のルーティン'), findsOneWidget);

    await tester.tap(find.text('新しく作る'));
    await tester.pumpAndSettle();
    
    expect(find.text('ルーティン作成'), findsOneWidget);

    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('入力してください'), findsOneWidget);
  });
}
