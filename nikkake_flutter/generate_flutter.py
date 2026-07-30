import os

base_dir = "/Users/tatsuaki/dev/hotl-star/nikkake_flutter/lib"
test_dir = "/Users/tatsuaki/dev/hotl-star/nikkake_flutter/test"
integration_test_dir = "/Users/tatsuaki/dev/hotl-star/nikkake_flutter/integration_test"

os.makedirs(os.path.join(base_dir, "constants"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "models"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "providers"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "screens"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "services"), exist_ok=True)
os.makedirs(test_dir, exist_ok=True)
os.makedirs(integration_test_dir, exist_ok=True)

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content.strip() + '\n')

colors_dart = """
import 'package:flutter/material.dart';

class AppColors {
  static const darkBackground = Color(0xFF0F0F14);
  static const darkSurface = Color(0xFF1A1A24);
  static const darkSurfaceElevated = Color(0xFF24243A);
  static const darkPrimary = Color(0xFF6C5CE7);
  static const darkPrimaryLight = Color(0xFFA29BFE);
  static const darkSecondary = Color(0xFF00B894);
  static const darkSecondaryLight = Color(0xFF55EFC4);
  static const darkAccent = Color(0xFFFDCB6E);
  static const darkAccentLight = Color(0xFFFFEAA7);
  static const darkTextPrimary = Color(0xFFF0F0F0);
  static const darkTextSecondary = Color(0xFFA0A0B0);
  static const darkSuccess = Color(0xFF55EFC4);
  static const darkWarning = Color(0xFFFFEAA7);
  static const darkError = Color(0xFFFF8A8A);
  static const darkBorder = Color(0x1AFFFFFF);

  static const lightBackground = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFF5F5F5);
  static const lightPrimary = Color(0xFF6C5CE7);
  static const lightPrimaryLight = Color(0xFFA29BFE);
  static const lightSecondary = Color(0xFF00B894);
  static const lightSecondaryLight = Color(0xFF55EFC4);
  static const lightAccent = Color(0xFFFDCB6E);
  static const lightAccentLight = Color(0xFFFFEAA7);
  static const lightTextPrimary = Color(0xFF2D3436);
  static const lightTextSecondary = Color(0xFF636E72);
  static const lightSuccess = Color(0xFF00B894);
  static const lightWarning = Color(0xFFFDCB6E);
  static const lightError = Color(0xFFD63031);
  static const lightBorder = Color(0x1A000000);
}

ThemeData getAppTheme(bool isDark) {
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
    primaryColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: Colors.white,
      secondary: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
      onSecondary: Colors.white,
      error: isDark ? AppColors.darkError : AppColors.lightError,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
"""

models_dart = """
class User {
  final String id;
  final String email;
  User({required this.id, required this.email});
}

class Routine {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String frequencyType;
  final int frequencyValue;
  final bool isActive;

  Routine({
    required this.id,
    required this.name,
    required this.icon,
    this.color = '#ff0000',
    this.frequencyType = 'daily',
    this.frequencyValue = 1,
    this.isActive = true,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String? ?? '#ff0000',
      frequencyType: json['frequency_type'] as String? ?? 'daily',
      frequencyValue: json['frequency_value'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'frequency_type': frequencyType,
      'frequency_value': frequencyValue,
      'is_active': isActive,
    };
  }
}

class RoutineLog {
  final String logDate;
  final String status;
  
  RoutineLog({required this.logDate, required this.status});
  
  factory RoutineLog.fromJson(Map<String, dynamic> json) {
    return RoutineLog(
      logDate: json['log_date'] as String,
      status: json['status'] as String,
    );
  }
}
"""

services_dart = """
import '../models/models.dart';

abstract class ApiService {
  Future<User?> getSession();
  Future<User> login(String email, String password);
  Future<User> register(String email, String password);
  Future<List<Routine>> fetchRoutines();
  Future<Routine> createRoutine(Map<String, dynamic> data);
  Future<List<RoutineLog>> fetchRoutineLogs();
}

// Concrete implementation would use supabase here, but we will inject mocks for testing.
class SupabaseService implements ApiService {
  @override
  Future<User?> getSession() async {
    // Implement supabase getSession
    return null;
  }
  @override
  Future<User> login(String email, String password) async {
    return User(id: 'dummy', email: email);
  }
  @override
  Future<User> register(String email, String password) async {
    return User(id: 'dummy', email: email);
  }
  @override
  Future<List<Routine>> fetchRoutines() async {
    return [];
  }
  @override
  Future<Routine> createRoutine(Map<String, dynamic> data) async {
    return Routine(id: 'new', name: data['name'], icon: '🔥');
  }
  @override
  Future<List<RoutineLog>> fetchRoutineLogs() async {
    return [];
  }
}
"""

providers_dart = """
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  User? _user;
  bool _isLoading = false;

  AuthProvider(this.api);

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();
    _user = await api.getSession();
    _isLoading = false;
    notifyListeners();
  }
  
  void setUser(User? u) {
    _user = u;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await api.login(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await api.register(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class RoutineProvider extends ChangeNotifier {
  final ApiService api;
  List<Routine> _routines = [];
  List<RoutineLog> _logs = [];

  RoutineProvider(this.api);

  List<Routine> get routines => _routines;
  List<RoutineLog> get logs => _logs;

  Future<void> fetchRoutines() async {
    _routines = await api.fetchRoutines();
    notifyListeners();
  }

  Future<void> fetchLogs() async {
    _logs = await api.fetchRoutineLogs();
    notifyListeners();
  }

  Future<void> createRoutine(String name) async {
    final r = await api.createRoutine({'name': name, 'icon': '🏋️'});
    _routines.add(r);
    notifyListeners();
  }
}
"""

main_dart = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'services/services.dart';
import 'providers/providers.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/routine_create_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/progress_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => SupabaseService()),
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiService>()),
          update: (_, api, auth) => auth ?? AuthProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiService, RoutineProvider>(
          create: (context) => RoutineProvider(context.read<ApiService>()),
          update: (_, api, provider) => provider ?? RoutineProvider(api),
        ),
      ],
      child: const NikkakeApp(),
    ),
  );
}

class NikkakeApp extends StatelessWidget {
  const NikkakeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nikkake',
      theme: getAppTheme(false),
      darkTheme: getAppTheme(true),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.user == null) {
            return const LoginScreen();
          }
          return const MainScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/routine/create': (context) => const RoutineCreateScreen(),
        '/workout': (context) => const WorkoutScreen(),
        '/progress': (context) => const ProgressScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _screens = [const HomeScreen(), const ProgressScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ルーティン'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '進捗状況'),
        ],
      ),
    );
  }
}
"""

login_screen_dart = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('毎日の日課を、習慣に。')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ElevatedButton(
              onPressed: () async {
                if (_email.text.isEmpty || _password.text.isEmpty) {
                  setState(() { _error = 'メールアドレスとパスワードを入力してください'; });
                  return;
                }
                await context.read<AuthProvider>().login(_email.text, _password.text);
              },
              child: const Text('ログイン'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/register');
              },
              child: const Text('アカウントをお持ちでない方はこちら'),
            )
          ],
        ),
      ),
    );
  }
}
"""

register_screen_dart = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ElevatedButton(
              onPressed: () async {
                if (_email.text.isEmpty || _password.text.isEmpty) {
                  setState(() { _error = 'すべての項目を入力してください'; });
                  return;
                }
                await context.read<AuthProvider>().register(_email.text, _password.text);
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('登録して始める'),
            ),
          ],
        ),
      ),
    );
  }
}
"""

home_screen_dart = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RoutineProvider>().fetchRoutines());
  }

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<RoutineProvider>().routines;
    return Scaffold(
      appBar: AppBar(title: const Text('今日のルーティン')),
      body: ListView.builder(
        itemCount: routines.length,
        itemBuilder: (context, index) {
          final r = routines[index];
          return ListTile(
            leading: Text(r.icon, style: const TextStyle(fontSize: 24)),
            title: Text(r.name),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/workout');
              },
              child: const Text('開始する'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/routine/create');
        },
        label: const Text('新しく作る'),
      ),
    );
  }
}
"""

routine_create_screen_dart = """
import 'package:flutter/material.dart';

class RoutineCreateScreen extends StatefulWidget {
  const RoutineCreateScreen({Key? key}) : super(key: key);

  @override
  State<RoutineCreateScreen> createState() => _RoutineCreateScreenState();
}

class _RoutineCreateScreenState extends State<RoutineCreateScreen> {
  final _name = TextEditingController();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルーティン作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'ルーティン名')),
            ElevatedButton(
              onPressed: () {
                if (_name.text.isEmpty) {
                  setState(() { _error = '入力してください'; });
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('作成する'),
            ),
          ],
        ),
      ),
    );
  }
}
"""

workout_screen_dart = """
import 'package:flutter/material.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ワークアウト')),
      body: const Center(
        child: Text('Workout in progress...'),
      ),
    );
  }
}
"""

progress_screen_dart = """
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RoutineProvider>().fetchLogs());
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<RoutineProvider>().logs;
    return Scaffold(
      appBar: AppBar(title: const Text('進捗状況')),
      body: Column(
        children: [
          const Text('完了したワークアウト', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${logs.length} 回', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          const Text('ボリューム推移（モック）'),
        ],
      ),
    );
  }
}
"""

auth_spec_dart = """
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
"""

routine_spec_dart = """
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
"""

workout_spec_dart = """
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
"""

write_file(os.path.join(base_dir, 'constants/colors.dart'), colors_dart)
write_file(os.path.join(base_dir, 'models/models.dart'), models_dart)
write_file(os.path.join(base_dir, 'services/services.dart'), services_dart)
write_file(os.path.join(base_dir, 'providers/providers.dart'), providers_dart)
write_file(os.path.join(base_dir, 'main.dart'), main_dart)
write_file(os.path.join(base_dir, 'screens/login_screen.dart'), login_screen_dart)
write_file(os.path.join(base_dir, 'screens/register_screen.dart'), register_screen_dart)
write_file(os.path.join(base_dir, 'screens/home_screen.dart'), home_screen_dart)
write_file(os.path.join(base_dir, 'screens/routine_create_screen.dart'), routine_create_screen_dart)
write_file(os.path.join(base_dir, 'screens/workout_screen.dart'), workout_screen_dart)
write_file(os.path.join(base_dir, 'screens/progress_screen.dart'), progress_screen_dart)

write_file(os.path.join(integration_test_dir, 'auth_test.dart'), auth_spec_dart)
write_file(os.path.join(integration_test_dir, 'routine_test.dart'), routine_spec_dart)
write_file(os.path.join(integration_test_dir, 'workout_test.dart'), workout_spec_dart)

print("All files generated successfully.")
