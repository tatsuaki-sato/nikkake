import '../models/models.dart';

abstract class ApiService {
  Future<User?> getSession();
  Future<User> login(String email, String password);
  Future<User> register(String email, String password);
  Future<List<Routine>> fetchRoutines();
  Future<Routine> createRoutine(Map<String, dynamic> data);
  Future<List<RoutineLog>> fetchRoutineLogs();
  
  // New RPC methods
  Future<Map<String, dynamic>> saveWorkoutLog(String routineId, int? durationSec, String status, String? notes, List<Map<String, dynamic>> exerciseLogs);
  Future<List<Map<String, dynamic>>> fetchRoutineHistory(String routineId);
}

// Concrete implementation would use supabase here, but we will inject mocks for testing.
class SupabaseService implements ApiService {
  @override
  Future<User?> getSession() async {
    // Implement supabase getSession
    return null;
  }
  @override
  Future<User> login(String email, String password) async {
    return User(id: 'dummy', email: email);
  }
  @override
  Future<User> register(String email, String password) async {
    return User(id: 'dummy', email: email);
  }
  @override
  Future<List<Routine>> fetchRoutines() async {
    return [];
  }
  @override
  Future<Routine> createRoutine(Map<String, dynamic> data) async {
    return Routine(id: 'new', name: data['name'], icon: '🔥');
  }
  @override
  Future<List<RoutineLog>> fetchRoutineLogs() async {
    return [];
  }
  @override
  Future<Map<String, dynamic>> saveWorkoutLog(String routineId, int? durationSec, String status, String? notes, List<Map<String, dynamic>> exerciseLogs) async {
    return {'success': true, 'routine_log_id': 'dummy_id'};
  }
  @override
  Future<List<Map<String, dynamic>>> fetchRoutineHistory(String routineId) async {
    return [];
  }
}
