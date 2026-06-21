class Wallet {
  final String id;
  final String ownerId;
  final String ownerType; // SYSTEM, USER_SALES, USER_COLLECTION, ACCOUNTANT_SITE
  final String? siteId;
  final double balance;

  Wallet({
    required this.id,
    required this.ownerId,
    required this.ownerType,
    this.siteId,
    required this.balance,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      ownerType: json['owner_type'] as String,
      siteId: json['site_id'] as String?,
      balance: (json['balance'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_type': ownerType,
      'site_id': siteId,
      'balance': balance,
    };
  }
}
