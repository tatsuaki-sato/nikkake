import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'data/local_db.dart';
import 'data/repository.dart';
import 'data/sync_service.dart';
import 'providers/app_state.dart';
import 'providers/auth_controller.dart';
import 'providers/workout_controller.dart';
import 'screens/main_screen.dart';

/// アプリのウィジェットツリー。
///
/// main.dart から分離してあるのは、テストから同じツリーを
/// 差し替えた依存（インメモリのストレージなど）で組み立てられるようにするため。
class NikkakeApp extends StatefulWidget {
  final LocalDb db;

  /// 未サインインでも全機能が動くので、認証は任意の依存として渡す
  final AuthController? authController;

  const NikkakeApp({super.key, required this.db, this.authController});

  @override
  State<NikkakeApp> createState() => _NikkakeAppState();
}

class _NikkakeAppState extends State<NikkakeApp> {
  late final Repository _repository = Repository(widget.db);
  late final AppState _appState = AppState(_repository);
  late final WorkoutController _workout = WorkoutController(_repository);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 初回起動時にプリセット種目と「いつものルーティン」を用意する。
    // これが終わればサインインの有無に関係なくアプリは完全に使える。
    await _appState.bootstrap();
    if (mounted) setState(() => _ready = true);

    // 以降はUIをブロックしない。認証確認は表示に必須ではない。
    unawaited(widget.authController?.initialize());
  }

  @override
  void dispose() {
    _workout.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Repository>.value(value: _repository),
        ChangeNotifierProvider<AppState>.value(value: _appState),
        ChangeNotifierProvider<WorkoutController>.value(value: _workout),
        if (widget.authController != null)
          ChangeNotifierProvider<AuthController>.value(value: widget.authController!),
      ],
      child: MaterialApp(
        title: 'nikkake',
        debugShowCheckedModeBanner: false,
        theme: getAppTheme(true),
        darkTheme: getAppTheme(true),
        home: _ready
            ? const MainScreen()
            : const Scaffold(
                backgroundColor: AppColors.darkBackground,
                body: Center(child: CircularProgressIndicator(key: Key('app-bootstrap'))),
              ),
      ),
    );
  }
}

/// SyncServiceを持たない環境（テスト等）でも組み立てられるようにするヘルパー
AuthController? buildAuthController(SyncService? syncService) {
  if (syncService == null) return null;
  return AuthController(syncService: syncService, auth: syncService.client.auth);
}

void unawaited(Future<void>? future) {
  // 意図的に待たないことを明示するためのヘルパー
}
