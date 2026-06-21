class AuditLog {
  final String id;
  final String userId;
  final String action;
  final String details;
  final String timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      details: json['details'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'details': details,
      'timestamp': timestamp,
    };
  }
}
