class CashCollection {
  final String id;
  final String collectedFromUserId;
  final String collectedByUserId;
  final double amount;
  final String? siteId;
  final String remarks;
  final String timestamp;

  CashCollection({
    required this.id,
    required this.collectedFromUserId,
    required this.collectedByUserId,
    required this.amount,
    this.siteId,
    required this.remarks,
    required this.timestamp,
  });

  factory CashCollection.fromJson(Map<String, dynamic> json) {
    return CashCollection(
      id: json['id'] as String,
      collectedFromUserId: json['collected_from_user_id'] as String,
      collectedByUserId: json['collected_by_user_id'] as String,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      siteId: json['site_id'] as String?,
      remarks: json['remarks'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collected_from_user_id': collectedFromUserId,
      'collected_by_user_id': collectedByUserId,
      'amount': amount,
      'site_id': siteId,
      'remarks': remarks,
      'timestamp': timestamp,
    };
  }
}
