import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'routines_screen.dart';
import 'settings_screen.dart';

/// タブの土台。RN版と同じ4タブ構成。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _titles = ['ホーム', 'ルーティン', '進捗', '設定'];

  @override
  Widget build(BuildContext context) {
    final body = switch (_index) {
      0 => const HomeScreen(),
      1 => const RoutinesScreen(),
      2 => const ProgressScreen(),
      _ => const SettingsScreen(),
    };

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(_titles[_index]),
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        // 他の画面から戻ってきたときに完了状態を即反映させる
        onTap: (i) {
          context.read<AppState>().refresh();
          setState(() => _index = i);
        },
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimaryLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 20)), label: 'ホーム'),
          BottomNavigationBarItem(icon: Text('📋', style: TextStyle(fontSize: 20)), label: 'ルーティン'),
          BottomNavigationBarItem(icon: Text('📈', style: TextStyle(fontSize: 20)), label: '進捗'),
          BottomNavigationBarItem(icon: Text('⚙️', style: TextStyle(fontSize: 20)), label: '設定'),
        ],
      ),
    );
  }
}
