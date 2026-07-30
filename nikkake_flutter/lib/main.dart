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
