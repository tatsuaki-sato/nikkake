import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/colors.dart';
import 'data/local_db.dart';
import 'data/backend.dart';
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

  /// テストから差し替えるための口。省略すると BACKEND から組み立てる
  final BackendSwitch? backend;

  const NikkakeApp({super.key, required this.db, this.authController, this.backend});

  @override
  State<NikkakeApp> createState() => _NikkakeAppState();
}

class _NikkakeAppState extends State<NikkakeApp> {
  late final BackendSwitch _backend = widget.backend ?? BackendSwitch(db: widget.db);
  late final AppState _appState = AppState(_backend);
  late final WorkoutController _workout = WorkoutController(_backend);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 初回起動時にプリセット種目と「いつものルーティン」を用意する。
    // これが終わればサインインの有無に関係なくアプリは完全に使える。
    //
    // サーバモードでも順序は同じ。登録を待ってから画面を出すと、
    // アプリを入れた直後に圏外だと1歩も動かなくなる。
    await _appState.bootstrap();
    if (mounted) setState(() => _ready = true);

    // 以降はUIをブロックしない。
    // サーバへの登録も認証確認も、表示には必要ない。
    unawaited(_registerThenRefresh());
    unawaited(widget.authController?.initialize());
  }

  /// 登録が終わるとデータ元がローカルからサーバへ切り替わる。
  /// 表示中の内容はローカル由来なので読み直す。
  Future<void> _registerThenRefresh() async {
    final registered = await _backend.registerInBackground();
    if (registered && mounted) await _appState.refresh();
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
        Provider<BackendSwitch>.value(value: _backend),
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

void unawaited(Future<void>? future) {
  // 意図的に待たないことを明示するためのヘルパー
}
