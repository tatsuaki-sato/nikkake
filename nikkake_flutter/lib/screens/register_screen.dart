import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_controller.dart';
import '../widgets/ui.dart';

/// アカウント作成。
/// 既にローカルにあるルーティンと記録は、作成後の初回同期でそのまま引き継がれる。
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
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
    if (password.length < 6) {
      setState(() => _error = 'パスワードは6文字以上にしてください');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    final error = await auth.signUp(
      email,
      password,
      displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error != null) return;

    // メール確認が必要な設定だとこの時点ではサインインが完了していない
    if (auth.user != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(title: const Text('アカウント作成')),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: AppCard(
            key: const Key('register-done'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '確認メールを送りました',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                const Text(
                  'メール内のリンクを開くとバックアップが有効になります。'
                  'それまでも、この端末での記録はこれまで通り続けられます。',
                  style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: Spacing.lg),
                AppButton(
                  label: 'アプリに戻る',
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('アカウント作成')),
      body: ListView(
        key: const Key('register-screen'),
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const AppCard(
            color: AppColors.darkSurfaceElevated,
            child: Text(
              '今この端末にあるルーティンと記録は、アカウント作成後にそのままクラウドへ引き継がれます。',
              style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.darkTextSecondary),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          ErrorText(_error),

          const Text('ニックネーム（任意）',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const Key('register-name'),
            controller: _nameController,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: 'にっかけ太郎'),
          ),
          const SizedBox(height: Spacing.md),

          const Text('メールアドレス',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const Key('register-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: 'example@email.com'),
          ),
          const SizedBox(height: Spacing.md),

          const Text('パスワード（6文字以上）',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)),
          const SizedBox(height: Spacing.sm),
          TextField(
            key: const Key('register-password'),
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(hintText: '••••••••'),
          ),
          const SizedBox(height: Spacing.lg),

          AppButton(
            key: const Key('register-submit'),
            label: 'アカウントを作る',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
