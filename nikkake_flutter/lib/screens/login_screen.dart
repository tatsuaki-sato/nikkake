import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_controller.dart';
import '../widgets/ui.dart';
import 'register_screen.dart';

/// サインイン画面。
///
/// この画面はアプリの入口ではない。設定から任意で開く「バックアップ設定」であり、
/// ここを飛ばしてもアプリの全機能が使えることを画面上でも明示している。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.read<AuthController>().signIn(email, password);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('バックアップを有効にする')),
      body: ListView(
        key: const Key('login-screen'),
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const Center(
            child: Column(
              children: [
                Text(
                  'nikkake',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkPrimaryLight,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Text('毎日の日課を、習慣に。',
                    style: TextStyle(fontSize: 14, color: AppColors.darkTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),

          const AppCard(
            key: Key('login-optional-notice'),
            color: AppColors.darkSurfaceElevated,
            child: Text(
              'サインインは任意です。しなくてもルーティンの作成も記録も全部使えます。'
              '機種変更やアプリの入れ直しで記録を失いたくない場合だけ設定してください。',
              style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.darkTextSecondary),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          ErrorText(_error),

          const Text('メールアドレス',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const Key('login-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: 'example@email.com'),
          ),
          const SizedBox(height: Spacing.md),

          const Text('パスワード', style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const Key('login-password'),
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: '••••••••'),
          ),
          const SizedBox(height: Spacing.lg),

          AppButton(
            key: const Key('login-submit'),
            label: 'サインイン',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: Spacing.md),

          Center(
            child: TextButton(
              key: const Key('login-to-register'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text('アカウントを作る'),
            ),
          ),

          AppButton(
            key: const Key('login-skip'),
            label: 'あとで設定する',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
