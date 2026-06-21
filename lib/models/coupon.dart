import 'coupon_history.dart';

class Coupon {
  final String id;
  final String code;
  final String profileId;
  final String? siteId;
  final double cost;
  final double salePrice;
  final String status;
  final String? soldByUserId;
  final String? customerName;
  final String? customerPhone;
  final String? soldAt;
  final String createdAt;
  final List<CouponHistory> history;

  Coupon({
    required this.id,
    required this.code,
    required this.profileId,
    this.siteId,
    required this.cost,
    required this.salePrice,
    required this.status,
    this.soldByUserId,
    this.customerName,
    this.customerPhone,
    this.soldAt,
    required this.createdAt,
    required this.history,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    var rawHistory = json['coupon_history'] as List?;
    List<CouponHistory> parsedHistory = [];
    if (rawHistory != null) {
      parsedHistory = rawHistory
          .map((h) => CouponHistory.fromJson(h as Map<String, dynamic>))
          .toList();
    }
    
    return Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      profileId: json['profile_id'] as String,
      siteId: json['site_id'] as String?,
      cost: (json['cost'] as num? ?? 0).toDouble(),
      salePrice: (json['sale_price'] as num? ?? 0).toDouble(),
      status: json['status'] as String,
      soldByUserId: json['sold_by_user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      soldAt: json['sold_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      history: parsedHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'profile_id': profileId,
      'site_id': siteId,
      'cost': cost,
      'sale_price': salePrice,
      'status': status,
      'sold_by_user_id': soldByUserId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'sold_at': soldAt,
      'created_at': createdAt,
    };
  }
}
