class Site {
  final String id;
  final String name;
  final String location;
  final String status;
  final bool smsEnabled;
  final String? subscriptionExpiry; // ISO-8601 string or null (null = lifetime)

  Site({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.smsEnabled,
    this.subscriptionExpiry,
  });

  /// Returns true when the subscription is active or has no expiry set (lifetime).
  bool get isSubscriptionActive {
    if (subscriptionExpiry == null) return true;
    return DateTime.parse(subscriptionExpiry!).isAfter(DateTime.now());
  }

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      status: json['status'] as String,
      smsEnabled: json['sms_enabled'] != false,
      subscriptionExpiry: json['subscription_expiry'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'status': status,
      'sms_enabled': smsEnabled,
      'subscription_expiry': subscriptionExpiry,
    };
  }
}
