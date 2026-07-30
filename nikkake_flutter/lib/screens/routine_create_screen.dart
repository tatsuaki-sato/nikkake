import 'package:flutter/material.dart';

class RoutineCreateScreen extends StatefulWidget {
  const RoutineCreateScreen({Key? key}) : super(key: key);

  @override
  State<RoutineCreateScreen> createState() => _RoutineCreateScreenState();
}

class _RoutineCreateScreenState extends State<RoutineCreateScreen> {
  final _name = TextEditingController();
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ルーティン作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'ルーティン名')),
            ElevatedButton(
              onPressed: () {
                if (_name.text.isEmpty) {
                  setState(() { _error = '入力してください'; });
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('作成する'),
            ),
          ],
        ),
      ),
    );
  }
}
