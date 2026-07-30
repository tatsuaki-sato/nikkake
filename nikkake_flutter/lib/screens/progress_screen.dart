import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RoutineProvider>().fetchLogs());
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<RoutineProvider>().logs;
    return Scaffold(
      appBar: AppBar(title: const Text('進捗状況')),
      body: Column(
        children: [
          const Text('完了したワークアウト', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${logs.length} 回', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          const Text('ボリューム推移（モック）'),
        ],
      ),
    );
  }
}
