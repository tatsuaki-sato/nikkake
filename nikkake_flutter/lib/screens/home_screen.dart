import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<RoutineProvider>().fetchRoutines());
  }

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<RoutineProvider>().routines;
    return Scaffold(
      appBar: AppBar(title: const Text('今日のルーティン')),
      body: ListView.builder(
        itemCount: routines.length,
        itemBuilder: (context, index) {
          final r = routines[index];
          return ListTile(
            leading: Text(r.icon, style: const TextStyle(fontSize: 24)),
            title: Text(r.name),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/workout');
              },
              child: const Text('開始する'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/routine/create');
        },
        label: const Text('新しく作る'),
      ),
    );
  }
}
