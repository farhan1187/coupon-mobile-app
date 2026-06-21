class AppTransaction {
  final String id;
  final String? fromWalletId;
  final String? toWalletId;
  final double amount;
  final String type; // SALE, CASH_COLLECTION, ADJUSTMENT, REVERSAL
  final String? siteId;
  final String? relatedTransactionId;
  final String remarks;
  final String createdByUserId;
  final String timestamp;

  AppTransaction({
    required this.id,
    this.fromWalletId,
    this.toWalletId,
    required this.amount,
    required this.type,
    this.siteId,
    this.relatedTransactionId,
    required this.remarks,
    required this.createdByUserId,
    required this.timestamp,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) {
    return AppTransaction(
      id: json['id'] as String,
      fromWalletId: json['from_wallet_id'] as String?,
      toWalletId: json['to_wallet_id'] as String?,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      type: json['type'] as String,
      siteId: json['site_id'] as String?,
      relatedTransactionId: json['related_transaction_id'] as String?,
      remarks: json['remarks'] as String? ?? '',
      createdByUserId: json['created_by_user_id'] as String? ?? 'system',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'type': type,
      'site_id': siteId,
      'related_transaction_id': relatedTransactionId,
      'remarks': remarks,
      'created_by_user_id': createdByUserId,
      'timestamp': timestamp,
    };
  }
}
