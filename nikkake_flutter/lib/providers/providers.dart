import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  User? _user;
  bool _isLoading = false;

  AuthProvider(this.api);

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();
    _user = await api.getSession();
    _isLoading = false;
    notifyListeners();
  }
  
  void setUser(User? u) {
    _user = u;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await api.login(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await api.register(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class RoutineProvider extends ChangeNotifier {
  final ApiService api;
  List<Routine> _routines = [];
  List<RoutineLog> _logs = [];

  RoutineProvider(this.api);

  List<Routine> get routines => _routines;
  List<RoutineLog> get logs => _logs;

  Future<void> fetchRoutines() async {
    _routines = await api.fetchRoutines();
    notifyListeners();
  }

  Future<void> fetchLogs() async {
    _logs = await api.fetchRoutineLogs();
    notifyListeners();
  }

  Future<void> createRoutine(String name) async {
    final r = await api.createRoutine({'name': name, 'icon': '🏋️'});
    _routines.add(r);
    notifyListeners();
  }
}
