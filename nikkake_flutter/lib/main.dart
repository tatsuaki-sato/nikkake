import 'package:flutter/material.dart';
import 'app.dart';
import 'data/backend.dart';
import 'data/local_db.dart';
import 'data/local_store.dart';
import 'providers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.open();
  final db = LocalDb(store);

  // ローカルモードでもサーバモードでも、ここで例外を投げて起動を止めない。
  // 止めるのは「ログイン不要で使える」という要件に反する。
  final backend = BackendSwitch(db: db);

  runApp(NikkakeApp(
    db: db,
    backend: backend,
    authController: AuthController(backend),
  ));
}
