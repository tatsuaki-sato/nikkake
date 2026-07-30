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
