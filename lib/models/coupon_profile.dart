class CouponProfile {
  final String id;
  final String name;
  final int validityDays;
  final double price;
  final double salePrice;
  final double costPrice;
  final String description;
  final String status;

  CouponProfile({
    required this.id,
    required this.name,
    required this.validityDays,
    required this.price,
    required this.salePrice,
    required this.costPrice,
    required this.description,
    required this.status,
  });

  factory CouponProfile.fromJson(Map<String, dynamic> json) {
    return CouponProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      validityDays: json['validity_days'] as int? ?? 0,
      price: (json['price'] as num? ?? 0).toDouble(),
      salePrice: (json['sale_price'] as num? ?? 0).toDouble(),
      costPrice: (json['cost_price'] as num? ?? 0).toDouble(),
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'validity_days': validityDays,
      'price': price,
      'sale_price': salePrice,
      'cost_price': costPrice,
      'description': description,
      'status': status,
    };
  }
}
