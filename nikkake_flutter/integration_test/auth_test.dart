import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:nikkake_flutter/main.dart';
import 'package:nikkake_flutter/services/services.dart';
import 'package:nikkake_flutter/providers/providers.dart';
import 'package:nikkake_flutter/models/models.dart';

class MockApiService implements ApiService {
  User? currentUser;
  @override
  Future<User?> getSession() async => currentUser;
  @override
  Future<User> login(String email, String password) async {
    currentUser = User(id: 'test-user', email: email);
    return currentUser!;
  }
  @override
  Future<User> register(String email, String password) async {
    currentUser = User(id: 'test-user', email: email);
    return currentUser!;
  }
  @override
  Future<List<Routine>> fetchRoutines() async => [];
  @override
  Future<Routine> createRoutine(Map<String, dynamic> data) async => Routine(id: 'new', name: 'new', icon: '🔥');
  @override
  Future<List<RoutineLog>> fetchRoutineLogs() async => [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ログイン画面の初期表示と未入力エラー', (WidgetTester tester) async {
    final mockApi = MockApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          ChangeNotifierProvider(create: (_) => AuthProvider(mockApi)),
          ChangeNotifierProvider(create: (_) => RoutineProvider(mockApi)),
        ],
        child: const NikkakeApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('毎日の日課を、習慣に。'), findsOneWidget);

    await tester.tap(find.text('ログイン'));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスとパスワードを入力してください'), findsOneWidget);
  });

  testWidgets('新規登録画面への遷移と未入力エラー', (WidgetTester tester) async {
    final mockApi = MockApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApi),
          ChangeNotifierProvider(create: (_) => AuthProvider(mockApi)),
          ChangeNotifierProvider(create: (_) => RoutineProvider(mockApi)),
        ],
        child: const NikkakeApp(),
      ),
    );

    await tester.pumpAndSettle();
    
    await tester.tap(find.text('アカウントをお持ちでない方はこちら'));
    await tester.pumpAndSettle();
    
    expect(find.text('アカウント作成'), findsOneWidget);

    await tester.tap(find.text('登録して始める'));
    await tester.pumpAndSettle();

    expect(find.text('すべての項目を入力してください'), findsOneWidget);
  });
}
