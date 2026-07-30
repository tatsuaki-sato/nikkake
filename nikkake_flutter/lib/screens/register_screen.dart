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
