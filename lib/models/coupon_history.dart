class CouponHistory {
  final String action;
  final String details;
  final String userId;
  final String timestamp;

  CouponHistory({
    required this.action,
    required this.details,
    required this.userId,
    required this.timestamp,
  });

  factory CouponHistory.fromJson(Map<String, dynamic> json) {
    return CouponHistory(
      action: json['action'] as String? ?? '',
      details: json['details'] as String? ?? '',
      userId: (json['user_id'] ?? json['user']) as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'details': details,
      'user_id': userId,
      'timestamp': timestamp,
    };
  }
}
