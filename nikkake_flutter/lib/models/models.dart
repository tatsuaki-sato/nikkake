class User {
  final String id;
  final String email;
  User({required this.id, required this.email});
}

class Routine {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String frequencyType;
  final int frequencyValue;
  final bool isActive;

  Routine({
    required this.id,
    required this.name,
    required this.icon,
    this.color = '#ff0000',
    this.frequencyType = 'daily',
    this.frequencyValue = 1,
    this.isActive = true,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String? ?? '#ff0000',
      frequencyType: json['frequency_type'] as String? ?? 'daily',
      frequencyValue: json['frequency_value'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'frequency_type': frequencyType,
      'frequency_value': frequencyValue,
      'is_active': isActive,
    };
  }
}

class RoutineLog {
  final String logDate;
  final String status;
  
  RoutineLog({required this.logDate, required this.status});
  
  factory RoutineLog.fromJson(Map<String, dynamic> json) {
    return RoutineLog(
      logDate: json['log_date'] as String,
      status: json['status'] as String,
    );
  }
}
