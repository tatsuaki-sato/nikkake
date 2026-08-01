import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'data/local_db.dart';
import 'data/local_store.dart';
import 'data/sync_service.dart';
import 'providers/auth_controller.dart';

/// Supabaseはバックアップ先としてのみ使う。
/// anonキーはクライアントに埋め込む前提の公開値で、行単位のアクセス制御はRLSが担う。
const supabaseUrl = 'https://igptzltkydyghneioedm.supabase.co';
/// supabase_flutter 2.16 以降は publishableKey が正式名称。値は同じ anon キー
const supabasePublishableKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlncHR6bHRreWR5Z2huZWlvZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDMyNjEsImV4cCI6MjA5OTI3OTI2MX0.pNprCQcr4GkAY86VhF9JUHYtpGxavQxDJjpodea1dAE';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.open();
  final db = LocalDb(store);

  // Supabaseの初期化に失敗しても、ローカルモードでアプリは完全に動く。
  // ここで例外を投げて起動を止めるのは「ログイン不要で使える」という要件に反する。
  AuthController? authController;
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    final client = Supabase.instance.client;
    authController = AuthController(syncService: SyncService(db, client), auth: client.auth);
  } catch (_) {
    authController = null;
  }

  runApp(NikkakeApp(db: db, authController: authController));
}
