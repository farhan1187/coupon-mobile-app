import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site.dart';
import '../models/coupon_profile.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/cash_collection.dart';
import '../models/audit_log.dart';
import '../models/settings.dart';
import '../models/coupon.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String _uid() {
    return 'id-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
  }

  String _txid() {
    return 'tx-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
  }

  // ── Database Sync ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDb() async {
    try {
      final results = await Future.wait<dynamic>([
        _client.from('sites').select('*').order('name'),
        _client.from('coupon_profiles').select('*').order('name'),
        _client.from('users').select('*').order('name'),
        _client.from('user_sites').select('*'),
        _client.from('site_prices').select('*'),
        _client.from('coupons').select('*, coupon_history(*)').order('created_at', ascending: false),
        _client.from('wallets').select('*'),
        _client.from('transactions').select('*').order('timestamp', ascending: false).limit(500),
        _client.from('audit_logs').select('*').order('timestamp', ascending: false).limit(200),
        _client.from('settings').select('*').limit(1),
        _client.from('cash_collections').select('*').order('timestamp', ascending: false),
      ]);

      final List<dynamic> rawSites = results[0] as List<dynamic>;
      final List<dynamic> rawProfiles = results[1] as List<dynamic>;
      final List<dynamic> rawUsers = results[2] as List<dynamic>;
      final List<dynamic> rawUserSites = results[3] as List<dynamic>;
      final List<dynamic> rawSitePrices = results[4] as List<dynamic>;
      final List<dynamic> rawCoupons = results[5] as List<dynamic>;
      final List<dynamic> rawWallets = results[6] as List<dynamic>;
      final List<dynamic> rawTransactions = results[7] as List<dynamic>;
      final List<dynamic> rawAuditLogs = results[8] as List<dynamic>;
      final List<dynamic> rawSettingsRows = results[9] as List<dynamic>;
      final List<dynamic> rawCashCollections = results[10] as List<dynamic>;

      final sites = rawSites.map((s) => Site.fromJson(s as Map<String, dynamic>)).toList();
      final profiles = rawProfiles.map((p) => CouponProfile.fromJson(p as Map<String, dynamic>)).toList();
      final users = rawUsers.map((u) => AppUser.fromJson(u as Map<String, dynamic>)).toList();
      
      final userSites = rawUserSites.map((us) => {
        'userId': us['user_id'] as String,
        'siteId': us['site_id'] as String,
      }).toList();

      final sitePrices = rawSitePrices.map((sp) => {
        'siteId': sp['site_id'] as String,
        'profileId': sp['profile_id'] as String,
        'salePrice': (sp['sale_price'] as num? ?? 0).toDouble(),
        'costPrice': (sp['cost_price'] as num? ?? 0).toDouble(),
      }).toList();

      final coupons = rawCoupons.map((c) => Coupon.fromJson(c as Map<String, dynamic>)).toList();
      final wallets = rawWallets.map((w) => Wallet.fromJson(w as Map<String, dynamic>)).toList();
      final transactions = rawTransactions.map((t) => AppTransaction.fromJson(t as Map<String, dynamic>)).toList();
      final auditLogs = rawAuditLogs.map((a) => AuditLog.fromJson(a as Map<String, dynamic>)).toList();
      
      final settings = rawSettingsRows.isNotEmpty 
          ? SystemSettings.fromJson(rawSettingsRows[0] as Map<String, dynamic>)
          : SystemSettings(
              lowStockThreshold: 5,
              telegramWebhookUrl: '',
              whatsappNotificationEnabled: false,
              twoFactorEnabled: false,
              smsProvider: 'twilio',
              twilioAccountSid: '',
              twilioAuthToken: '',
              twilioFromNumber: '',
              msegatUserName: '',
              msegatApiKey: '',
              msegatSenderName: '',
            );

      final cashCollections = rawCashCollections.map((cc) => CashCollection.fromJson(cc as Map<String, dynamic>)).toList();

      return {
        'sites': sites,
        'couponProfiles': profiles,
        'users': users,
        'userSites': userSites,
        'sitePrices': sitePrices,
        'coupons': coupons,
        'wallets': wallets,
        'transactions': transactions,
        'auditLogs': auditLogs,
        'settings': settings,
        'cashCollections': cashCollections,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ── Logging ────────────────────────────────────────────────────────────────
  Future<void> logAction(String userId, String action, String details) async {
    await _client.from('audit_logs').insert({
      'id': _uid(),
      'user_id': userId,
      'action': action,
      'details': details,
    });
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  Future<AppUser?> findUser(String username) async {
    final List<dynamic> data = await _client
        .from('users')
        .select('*')
        .ilike('username', username);
    if (data.isEmpty) return null;
    return AppUser.fromJson(data[0] as Map<String, dynamic>);
  }

  // ── Site Management ────────────────────────────────────────────────────────
  Future<void> addSite(String name, String location, String currentUserId) async {
    final id = 'site-${name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('sites').insert({
      'id': id,
      'name': name,
      'location': location,
      'status': 'Active',
    });
    await logAction(currentUserId, 'SITE_CREATION', 'Created site $name');
  }

  Future<void> updateSiteSmsEnabled(String siteId, bool enabled, String currentUserId) async {
    await _client.from('sites').update({
      'sms_enabled': enabled,
    }).eq('id', siteId);
    await logAction(currentUserId, 'SITE_SMS_TOGGLE', 'SMS ${enabled ? "enabled" : "disabled"} for site $siteId');
  }

  Future<void> deleteSite(String siteId, String currentUserId) async {
    final Map<String, dynamic>? site = await _client.from('sites').select('name').eq('id', siteId).maybeSingle();
    await _client.from('sites').delete().eq('id', siteId);
    await logAction(currentUserId, 'SITE_DELETION', 'Deleted site: ${site?["name"] ?? siteId}');
  }

  // ── Profile Management ─────────────────────────────────────────────────────
  Future<void> addCouponProfile(CouponProfile profile, String currentUserId) async {
    final id = 'cp-${profile.name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('coupon_profiles').insert({
      'id': id,
      'name': profile.name,
      'validity_days': profile.validityDays,
      'price': profile.price,
      'sale_price': profile.salePrice,
      'cost_price': profile.costPrice,
      'description': profile.description,
      'status': 'Active',
    });
    await logAction(currentUserId, 'PROFILE_CREATION', 'Created profile ${profile.name}');
  }

  Future<void> deleteCouponProfile(String profileId, String currentUserId) async {
    final Map<String, dynamic>? profile = await _client.from('coupon_profiles').select('name').eq('id', profileId).maybeSingle();
    await _client.from('coupon_profiles').delete().eq('id', profileId);
    await logAction(currentUserId, 'PROFILE_DELETION', 'Deleted profile: ${profile?["name"] ?? profileId}');
  }

  Future<void> updateSitePrice(String siteId, String profileId, double salePrice, double costPrice, String currentUserId) async {
    await _client.from('site_prices').upsert({
      'site_id': siteId,
      'profile_id': profileId,
      'sale_price': salePrice,
      'cost_price': costPrice,
    });
    await logAction(currentUserId, 'UPDATE_SITE_PRICE', 'Updated price for profile $profileId at site $siteId');
  }

  Future<void> assignProfileToSite(String siteId, String profileId, String currentUserId) async {
    final Map<String, dynamic>? profile = await _client.from('coupon_profiles').select('sale_price, cost_price').eq('id', profileId).maybeSingle();
    await _client.from('site_prices').upsert({
      'site_id': siteId,
      'profile_id': profileId,
      'sale_price': profile?['sale_price'] ?? 0.0,
      'cost_price': profile?['cost_price'] ?? 0.0,
    });
    await logAction(currentUserId, 'PROFILE_ASSIGNED', 'Assigned profile $profileId to site $siteId');
  }

  Future<void> unassignProfileFromSite(String siteId, String profileId, String currentUserId) async {
    await _client.from('site_prices').delete().eq('site_id', siteId).eq('profile_id', profileId);
    await logAction(currentUserId, 'PROFILE_UNASSIGNED', 'Unassigned profile $profileId from site $siteId');
  }

  // ── User Management ────────────────────────────────────────────────────────
  Future<void> addUser(AppUser user, List<String> siteIds, String currentUserId) async {
    final id = 'u-${user.username.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('users').insert({
      'id': id,
      'username': user.username,
      'password': user.password,
      'role': user.role,
      'name': user.name,
      'two_fa_enabled': false,
    });

    final List<Map<String, dynamic>> wallets = [];
    if (user.role == 'Staff') {
      wallets.add({'id': 'w-$id-sales', 'owner_id': id, 'owner_type': 'USER_SALES', 'balance': 0});
    } else if (user.role == 'Super Staff') {
      wallets.add({'id': 'w-$id-sales', 'owner_id': id, 'owner_type': 'USER_SALES', 'balance': 0});
      wallets.add({'id': 'w-$id-collection', 'owner_id': id, 'owner_type': 'USER_COLLECTION', 'balance': 0});
    } else {
      wallets.add({'id': 'w-$id-collection', 'owner_id': id, 'owner_type': 'USER_COLLECTION', 'balance': 0});
    }

    if (wallets.isNotEmpty) {
      await _client.from('wallets').insert(wallets);
    }
    if (siteIds.isNotEmpty) {
      final userSites = siteIds.map((sid) => {'user_id': id, 'site_id': sid}).toList();
      await _client.from('user_sites').insert(userSites);
    }
    await logAction(currentUserId, 'USER_CREATION', 'Created user ${user.username} (${user.role})');
  }

  Future<void> deleteUser(String userId, String currentUserId) async {
    if (userId == 'u-sysadmin') throw Exception('Cannot delete system administrator');
    final Map<String, dynamic>? user = await _client.from('users').select('username').eq('id', userId).maybeSingle();
    await _client.from('users').delete().eq('id', userId);
    await logAction(currentUserId, 'USER_DELETION', 'Deleted user: ${user?["username"] ?? userId}');
  }

  Future<void> linkUserToSite(String userId, String siteId, String currentUserId) async {
    try {
      await _client.from('user_sites').insert({
        'user_id': userId,
        'site_id': siteId,
      });
      await logAction(currentUserId, 'USER_LINK', 'Linked user $userId to site $siteId');
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('User already linked to this site');
      rethrow;
    }
  }

  Future<void> unlinkUserFromSite(String userId, String siteId, String currentUserId) async {
    await _client.from('user_sites').delete().eq('user_id', userId).eq('site_id', siteId);
    await logAction(currentUserId, 'USER_UNLINK', 'Unlinked user $userId from site $siteId');
  }

  // ── POS/Sales ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sellCoupon({
    required String siteId,
    required String profileId,
    required String soldByUserId,
    required String customerName,
    required String customerPhone,
    required String remarks,
  }) async {
    // 1. Find an available coupon
    final List<dynamic> couponsData = await _client
        .from('coupons')
        .select('*')
        .eq('site_id', siteId)
        .eq('profile_id', profileId)
        .eq('status', 'Available')
        .limit(1);

    if (couponsData.isEmpty) {
      throw Exception('No coupons available for this profile at this site');
    }
    final rawCoupon = couponsData[0] as Map<String, dynamic>;

    // 2. Perform atomic update
    final walletId = 'w-$soldByUserId-sales';
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final List<dynamic> updateResult = await _client
        .from('coupons')
        .update({
          'status': 'Sold',
          'sold_by_user_id': soldByUserId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'sold_at': timestamp,
        })
        .eq('id', rawCoupon['id'] as String)
        .eq('status', 'Available')
        .select();

    if (updateResult.isEmpty) {
      throw Exception('Coupon was already sold — please try again');
    }

    final double salePrice = (rawCoupon['sale_price'] as num? ?? 0.0).toDouble();
    final String code = rawCoupon['code'] as String;

    // 3. Fetch wallets
    final walletResults = await Future.wait<dynamic>([
      _client.from('wallets').select('id, balance').eq('id', walletId).maybeSingle(),
      _client.from('wallets').select('balance').eq('id', 'w-system').maybeSingle(),
    ]);

    final Map<String, dynamic>? ew = walletResults[0];
    final Map<String, dynamic>? sw = walletResults[1];

    final double newUserBalance = (ew != null ? (ew['balance'] as num).toDouble() : 0.0) + salePrice;
    final txId = _txid();

    // 4. Update ledger and wallets
    await Future.wait<dynamic>([
      ew != null
          ? _client.from('wallets').update({'balance': newUserBalance}).eq('id', walletId)
          : _client.from('wallets').insert({'id': walletId, 'owner_id': soldByUserId, 'owner_type': 'USER_SALES', 'balance': salePrice}),
      sw != null
          ? _client.from('wallets').update({'balance': (sw['balance'] as num).toDouble() - salePrice}).eq('id', 'w-system')
          : Future.value(),
      _client.from('coupon_history').insert({
        'coupon_id': rawCoupon['id'] as String,
        'action': 'SOLD',
        'user_id': soldByUserId,
        'details': 'Sold to ${customerName.isNotEmpty ? customerName : "Walk-in"} for $salePrice AED. $remarks',
      }),
      _client.from('transactions').insert({
        'id': txId,
        'from_wallet_id': 'w-system',
        'to_wallet_id': walletId,
        'amount': salePrice,
        'type': 'SALE',
        'timestamp': timestamp,
        'remarks': 'Coupon sold: $code',
        'created_by_user_id': soldByUserId,
      }),
      logAction(soldByUserId, 'COUPON_SALE', 'Sold coupon $code for $salePrice AED. Customer: ${customerName.isNotEmpty ? customerName : "None"}'),
    ]);

    return {
      'success': true,
      'transactionId': txId,
      'couponCode': code,
    };
  }

  // ── Cash Collection ────────────────────────────────────────────────────────
  Future<void> collectCashFromStaff({
    required String collectedByUserId,
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    final Map<String, dynamic>? collector = await _client.from('users').select('role').eq('id', collectedByUserId).maybeSingle();
    final allowedRoles = ['Super Staff', 'Manager', 'Owner', 'Accountant'];
    if (collector == null || !allowedRoles.contains(collector['role'])) {
      throw Exception('Insufficient permissions to collect from Staff');
    }

    final staffWalletId = 'w-$collectedFromUserId-sales';
    final Map<String, dynamic>? staffWallet = await _client.from('wallets').select('balance').eq('id', staffWalletId).maybeSingle();
    if (staffWallet == null || (staffWallet['balance'] as num).toDouble() < amount) {
      throw Exception('Insufficient balance: ${staffWallet?["balance"] ?? 0} AED');
    }

    final superWalletId = 'w-$collectedByUserId-collection';
    final Map<String, dynamic>? superWallet = await _client.from('wallets').select('balance').eq('id', superWalletId).maybeSingle();

    final txId = _txid();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    await _client.from('wallets').update({
      'balance': (staffWallet['balance'] as num).toDouble() - amount,
    }).eq('id', staffWalletId);

    if (superWallet != null) {
      await _client.from('wallets').update({
        'balance': (superWallet['balance'] as num).toDouble() + amount,
      }).eq('id', superWalletId);
    } else {
      await _client.from('wallets').insert({
        'id': superWalletId,
        'owner_id': collectedByUserId,
        'owner_type': 'USER_COLLECTION',
        'balance': amount,
      });
    }

    await Future.wait<dynamic>([
      _client.from('transactions').insert({
        'id': txId,
        'from_wallet_id': staffWalletId,
        'to_wallet_id': superWalletId,
        'amount': amount,
        'type': 'CASH_COLLECTION',
        'timestamp': timestamp,
        'created_by_user_id': collectedByUserId,
        'remarks': remarks.isNotEmpty ? remarks : 'Collected $amount AED from staff',
      }),
      _client.from('cash_collections').insert({
        'id': _uid(),
        'collected_from_user_id': collectedFromUserId,
        'collected_by_user_id': collectedByUserId,
        'amount': amount,
        'site_id': siteId,
        'remarks': remarks,
        'timestamp': timestamp,
      }),
      logAction(collectedByUserId, 'CASH_COLLECTION', 'Collected $amount AED from staff $collectedFromUserId'),
    ]);
  }

  Future<void> collectCashFromSuperStaff({
    required String collectedByUserId,
    required String collectedFromUserId,
    required List<Map<String, dynamic>> splits, // [{ 'amount': double, 'siteId': String? }]
    required String remarks,
  }) async {
    final Map<String, dynamic>? collector = await _client.from('users').select('role').eq('id', collectedByUserId).maybeSingle();
    final allowedRoles = ['Manager', 'Owner', 'Accountant', 'Admin'];
    if (collector == null || !allowedRoles.contains(collector['role'])) {
      throw Exception('Insufficient permissions to collect from Super Staff');
    }

    final salesWalletId = 'w-$collectedFromUserId-sales';
    final collectionWalletId = 'w-$collectedFromUserId-collection';

    final walletsData = await Future.wait<dynamic>([
      _client.from('wallets').select('balance').eq('id', salesWalletId).maybeSingle(),
      _client.from('wallets').select('balance').eq('id', collectionWalletId).maybeSingle(),
    ]);

    final double salesBal = (walletsData[0]?['balance'] as num? ?? 0.0).toDouble();
    final double collectionBal = (walletsData[1]?['balance'] as num? ?? 0.0).toDouble();
    final double combinedBalance = salesBal + collectionBal;

    final double totalAmount = splits.fold(0.0, (sum, split) => sum + (split['amount'] as num).toDouble());
    if (combinedBalance < totalAmount) {
      throw Exception('Insufficient balance: $combinedBalance AED (sales: $salesBal, collected: $collectionBal)');
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final baseTxId = _txid();
    double remaining = totalAmount;

    if (salesBal > 0 && remaining > 0) {
      final deductFromSales = min(salesBal, remaining);
      await _client.from('wallets').update({
        'balance': salesBal - deductFromSales,
      }).eq('id', salesWalletId);
      remaining -= deductFromSales;
      await _client.from('transactions').insert({
        'id': '$baseTxId-sales-debit',
        'from_wallet_id': salesWalletId,
        'to_wallet_id': 'w-$collectedByUserId-collection',
        'amount': deductFromSales,
        'type': 'CASH_COLLECTION',
        'timestamp': timestamp,
        'remarks': '${remarks.isNotEmpty ? remarks : "Collected from Super Staff"} [own sales]',
        'created_by_user_id': collectedByUserId,
      });
    }

    if (collectionBal > 0 && remaining > 0) {
      final deductFromCollection = min(collectionBal, remaining);
      await _client.from('wallets').update({
        'balance': collectionBal - deductFromCollection,
      }).eq('id', collectionWalletId);
      remaining -= deductFromCollection;
      await _client.from('transactions').insert({
        'id': '$baseTxId-collection-debit',
        'from_wallet_id': collectionWalletId,
        'to_wallet_id': 'w-$collectedByUserId-collection',
        'amount': deductFromCollection,
        'type': 'CASH_COLLECTION',
        'timestamp': timestamp,
        'remarks': '${remarks.isNotEmpty ? remarks : "Collected from Super Staff"} [staff collections]',
        'created_by_user_id': collectedByUserId,
      });
    }

    final collectorWalletId = 'w-$collectedByUserId-collection';
    final Map<String, dynamic>? collWallet = await _client.from('wallets').select('balance').eq('id', collectorWalletId).maybeSingle();

    if (collWallet != null) {
      await _client.from('wallets').update({
        'balance': (collWallet['balance'] as num).toDouble() + totalAmount,
      }).eq('id', collectorWalletId);
    } else {
      await _client.from('wallets').insert({
        'id': collectorWalletId,
        'owner_id': collectedByUserId,
        'owner_type': 'USER_COLLECTION',
        'balance': totalAmount,
      });
    }

    await Future.wait<dynamic>([
      _client.from('cash_collections').insert({
        'id': _uid(),
        'collected_from_user_id': collectedFromUserId,
        'collected_by_user_id': collectedByUserId,
        'amount': totalAmount,
        'site_id': splits.isNotEmpty ? splits[0]['siteId'] : null,
        'remarks': remarks,
        'timestamp': timestamp,
      }),
      logAction(collectedByUserId, 'CASH_COLLECTION', 'Collected $totalAmount AED from Super Staff $collectedFromUserId (sales: $salesBal + collected: $collectionBal)'),
    ]);
  }

  Future<void> collectCashFromManager({
    required String collectedByUserId,
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    final Map<String, dynamic>? collector = await _client.from('users').select('role').eq('id', collectedByUserId).maybeSingle();
    final allowedRoles = ['Owner', 'Accountant'];
    if (collector == null || !allowedRoles.contains(collector['role'])) {
      throw Exception('Insufficient permissions to collect from Manager');
    }

    final managerWalletId = 'w-$collectedFromUserId-collection';
    final Map<String, dynamic>? mgrWallet = await _client.from('wallets').select('balance').eq('id', managerWalletId).maybeSingle();
    if (mgrWallet == null || (mgrWallet['balance'] as num).toDouble() < amount) {
      throw Exception('Insufficient balance: ${mgrWallet?["balance"] ?? 0} AED');
    }

    final collectorWalletId = 'w-$collectedByUserId-collection';
    final Map<String, dynamic>? collWallet = await _client.from('wallets').select('balance').eq('id', collectorWalletId).maybeSingle();

    final txId = _txid();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    await _client.from('wallets').update({
      'balance': (mgrWallet['balance'] as num).toDouble() - amount,
    }).eq('id', managerWalletId);

    if (collWallet != null) {
      await _client.from('wallets').update({
        'balance': (collWallet['balance'] as num).toDouble() + amount,
      }).eq('id', collectorWalletId);
    } else {
      await _client.from('wallets').insert({
        'id': collectorWalletId,
        'owner_id': collectedByUserId,
        'owner_type': 'USER_COLLECTION',
        'balance': amount,
      });
    }

    await Future.wait<dynamic>([
      _client.from('transactions').insert({
        'id': txId,
        'from_wallet_id': managerWalletId,
        'to_wallet_id': collectorWalletId,
        'amount': amount,
        'type': 'CASH_COLLECTION',
        'timestamp': timestamp,
        'created_by_user_id': collectedByUserId,
        'remarks': remarks.isNotEmpty ? remarks : 'Collected $amount AED from manager',
      }),
      _client.from('cash_collections').insert({
        'id': _uid(),
        'collected_from_user_id': collectedFromUserId,
        'collected_by_user_id': collectedByUserId,
        'amount': amount,
        'site_id': siteId,
        'remarks': remarks,
        'timestamp': timestamp,
      }),
      logAction(collectedByUserId, 'CASH_COLLECTION', 'Collected $amount AED from Manager $collectedFromUserId'),
    ]);
  }

  Future<void> collectCashFromOwner({
    required String collectedByUserId,
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    final Map<String, dynamic>? collector = await _client.from('users').select('role').eq('id', collectedByUserId).maybeSingle();
    if (collector == null || collector['role'] != 'Accountant') {
      throw Exception('Only Accountant can collect from Owner');
    }

    final ownerWalletId = 'w-$collectedFromUserId-collection';
    final Map<String, dynamic>? ownerWallet = await _client.from('wallets').select('balance').eq('id', ownerWalletId).maybeSingle();
    if (ownerWallet == null || (ownerWallet['balance'] as num).toDouble() < amount) {
      throw Exception('Insufficient balance: ${ownerWallet?["balance"] ?? 0} AED');
    }

    final collectorWalletId = 'w-$collectedByUserId-collection';
    final Map<String, dynamic>? collWallet = await _client.from('wallets').select('balance').eq('id', collectorWalletId).maybeSingle();

    final txId = _txid();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    await _client.from('wallets').update({
      'balance': (ownerWallet['balance'] as num).toDouble() - amount,
    }).eq('id', ownerWalletId);

    if (collWallet != null) {
      await _client.from('wallets').update({
        'balance': (collWallet['balance'] as num).toDouble() + amount,
      }).eq('id', collectorWalletId);
    } else {
      await _client.from('wallets').insert({
        'id': collectorWalletId,
        'owner_id': collectedByUserId,
        'owner_type': 'USER_COLLECTION',
        'balance': amount,
      });
    }

    await Future.wait<dynamic>([
      _client.from('transactions').insert({
        'id': txId,
        'from_wallet_id': ownerWalletId,
        'to_wallet_id': collectorWalletId,
        'amount': amount,
        'type': 'CASH_COLLECTION',
        'timestamp': timestamp,
        'created_by_user_id': collectedByUserId,
        'remarks': remarks.isNotEmpty ? remarks : 'Collected $amount AED from owner',
      }),
      _client.from('cash_collections').insert({
        'id': _uid(),
        'collected_from_user_id': collectedFromUserId,
        'collected_by_user_id': collectedByUserId,
        'amount': amount,
        'site_id': siteId,
        'remarks': remarks,
        'timestamp': timestamp,
      }),
      logAction(collectedByUserId, 'CASH_COLLECTION', 'Collected $amount AED from Owner $collectedFromUserId'),
    ]);
  }

  // ── Reversals & Adjustments ────────────────────────────────────────────────
  Future<void> walletAdjustment(String walletId, double amount, String remarks, String currentUserId) async {
    final Map<String, dynamic>? wallet = await _client.from('wallets').select('balance').eq('id', walletId).maybeSingle();
    if (wallet == null) throw Exception('Wallet not found');

    final double newBalance = (wallet['balance'] as num).toDouble() + amount;
    final txId = _txid();

    await _client.from('wallets').update({'balance': newBalance}).eq('id', walletId);

    await _client.from('transactions').insert({
      'id': txId,
      'from_wallet_id': amount >= 0 ? 'w-system' : walletId,
      'to_wallet_id': amount >= 0 ? walletId : 'w-system',
      'amount': amount.abs(),
      'type': 'ADJUSTMENT',
      'remarks': remarks.isNotEmpty ? remarks : 'Adjustment of $amount AED',
      'created_by_user_id': currentUserId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    await logAction(currentUserId, 'WALLET_ADJUSTMENT', 'Adjusted wallet $walletId by $amount AED');
  }

  Future<void> reverseTransaction(String transactionId, String reversedByUserId, String reason) async {
    final Map<String, dynamic>? orig = await _client.from('transactions').select('*').eq('id', transactionId).maybeSingle();
    if (orig == null) throw Exception('Transaction not found');
    if (orig['type'] == 'REVERSAL') throw Exception('Cannot reverse a reversal');

    final List<dynamic> already = await _client.from('transactions').select('id').eq('type', 'REVERSAL').eq('related_transaction_id', transactionId);
    if (already.isNotEmpty) throw Exception('Already reversed');

    final double amount = (orig['amount'] as num).toDouble();
    final String? fromWalletId = orig['from_wallet_id'] as String?;
    final String? toWalletId = orig['to_wallet_id'] as String?;

    if (toWalletId != null) {
      final Map<String, dynamic>? toW = await _client.from('wallets').select('balance').eq('id', toWalletId).maybeSingle();
      if (toW == null || (toW['balance'] as num).toDouble() < amount) {
        throw Exception('Recipient has insufficient funds');
      }
      await _client.from('wallets').update({
        'balance': (toW['balance'] as num).toDouble() - amount,
      }).eq('id', toWalletId);
    }

    if (fromWalletId != null) {
      final Map<String, dynamic>? fromW = await _client.from('wallets').select('balance').eq('id', fromWalletId).maybeSingle();
      if (fromW != null) {
        await _client.from('wallets').update({
          'balance': (fromW['balance'] as num).toDouble() + amount,
        }).eq('id', fromWalletId);
      }
    }

    final revTxId = _txid();
    await _client.from('transactions').insert({
      'id': revTxId,
      'from_wallet_id': toWalletId,
      'to_wallet_id': fromWalletId,
      'amount': amount,
      'type': 'REVERSAL',
      'related_transaction_id': transactionId,
      'remarks': 'REVERSAL of $transactionId. Reason: ${reason.isNotEmpty ? reason : "Correction"}',
      'created_by_user_id': reversedByUserId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    await logAction(reversedByUserId, 'TRANSACTION_REVERSAL', 'Reversed $transactionId. Reason: $reason');
  }

  // ── Import and Delete Coupons ──────────────────────────────────────────────
  Future<Map<String, dynamic>> importCoupons({
    required List<String> csvLines,
    required String importedByUserId,
    String? siteId,
  }) async {
    final results = await Future.wait<dynamic>([
      _client.from('coupon_profiles').select('*'),
      _client.from('site_prices').select('*'),
      _client.from('coupons').select('code'),
      _client.from('users').select('username').eq('id', importedByUserId).maybeSingle(),
    ]);

    final List<dynamic> profiles = results[0] as List<dynamic>;
    final List<dynamic> sitePrices = results[1] as List<dynamic>;
    final List<dynamic> existing = results[2] as List<dynamic>;
    final Map<String, dynamic>? userRow = results[3] as Map<String, dynamic>?;

    final String username = userRow?['username'] as String? ?? importedByUserId;
    final Set<String> existingCodes = Set.from(existing.map((c) => c['code'] as String));

    final List<Map<String, dynamic>> toInsert = [];
    final List<Map<String, dynamic>> historyToInsert = [];
    final List<String> errors = [];
    final timestamp = DateTime.now().toUtc().toIso8601String();

    for (int i = 0; i < csvLines.length; i++) {
      final line = csvLines[i];
      final parts = line.split(',').map((s) => s.trim()).toList();
      if (parts.length < 2) {
        errors.add('Row ${i + 1}: Need code, profile');
        continue;
      }
      final code = parts[0];
      final profileName = parts[1];

      if (code.isEmpty || profileName.isEmpty) {
        errors.add('Row ${i + 1}: Missing fields');
        continue;
      }

      final profile = profiles.firstWhere(
        (p) => (p['name'] as String).toLowerCase() == profileName.toLowerCase() ||
               (p['id'] as String).toLowerCase() == profileName.toLowerCase(),
        orElse: () => null,
      );

      if (profile == null) {
        errors.add('Row ${i + 1}: Profile "$profileName" not found');
        continue;
      }

      if (existingCodes.contains(code)) {
        errors.add('Row ${i + 1}: Duplicate code "$code"');
        continue;
      }

      double cost = parts.length > 2 && parts[2].isNotEmpty ? double.tryParse(parts[2]) ?? (profile['cost_price'] as num).toDouble() : (profile['cost_price'] as num).toDouble();
      double salePrice = parts.length > 3 && parts[3].isNotEmpty ? double.tryParse(parts[3]) ?? (profile['sale_price'] as num).toDouble() : (profile['sale_price'] as num).toDouble();

      if (siteId != null && parts.length <= 2) {
        final sitePrice = sitePrices.firstWhere(
          (sp) => sp['site_id'] == siteId && sp['profile_id'] == profile['id'],
          orElse: () => null,
        );
        if (sitePrice != null) {
          cost = (sitePrice['cost_price'] as num).toDouble();
          salePrice = (sitePrice['sale_price'] as num).toDouble();
        }
      }

      final couponId = 'c-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}-$i';
      existingCodes.add(code);

      toInsert.add({
        'id': couponId,
        'code': code,
        'profile_id': profile['id'],
        'site_id': siteId,
        'cost': cost,
        'sale_price': salePrice,
        'status': 'Available',
      });

      historyToInsert.add({
        'coupon_id': couponId,
        'action': 'CREATED',
        'details': 'Imported via CSV. Site: ${siteId ?? "none"}',
        'user_id': username,
        'timestamp': timestamp,
      });
    }

    if (toInsert.isNotEmpty) {
      await _client.from('coupons').insert(toInsert);
      await _client.from('coupon_history').insert(historyToInsert);
    }

    await logAction(importedByUserId, 'CSV_IMPORT', 'Imported ${toInsert.length} coupons. Errors: ${errors.length}');

    return {
      'success': true,
      'count': toInsert.length,
      'errors': errors,
    };
  }

  Future<void> deleteCoupon(String couponId, String currentUserId) async {
    final Map<String, dynamic>? coupon = await _client.from('coupons').select('code').eq('id', couponId).maybeSingle();
    await _client.from('coupons').delete().eq('id', couponId);
    await logAction(currentUserId, 'COUPON_DELETION', 'Deleted coupon: ${coupon?["code"] ?? couponId}');
  }

  Future<int> bulkDeleteCoupons(List<String> couponIds, String currentUserId) async {
    if (couponIds.isEmpty) return 0;
    await _client.from('coupons').delete().inFilter('id', couponIds);
    await logAction(currentUserId, 'BULK_COUPON_DELETION', 'Bulk deleted ${couponIds.length} coupons');
    return couponIds.length;
  }

  // ── Settings ───────────────────────────────────────────────────────────────
  Future<void> updateSettings(SystemSettings settings, String currentUserId) async {
    await _client.from('settings').update({
      'low_stock_threshold': settings.lowStockThreshold,
      'telegram_webhook_url': settings.telegramWebhookUrl,
      'whatsapp_notification_enabled': settings.whatsappNotificationEnabled,
      'two_factor_enabled': settings.twoFactorEnabled,
      'sms_provider': settings.smsProvider,
      'twilio_account_sid': settings.twilioAccountSid,
      'twilio_auth_token': settings.twilioAuthToken,
      'twilio_from_number': settings.twilioFromNumber,
      'msegat_user_name': settings.msegatUserName,
      'msegat_api_key': settings.msegatApiKey,
      'msegat_sender_name': settings.msegatSenderName,
    }).eq('id', 1);
    await logAction(currentUserId, 'SETTINGS_CHANGE', 'Updated system configuration');
  }

  Future<void> resetDb() async {
    await Future.wait<dynamic>([
      _client.from('transactions').delete().neq('id', ''),
      _client.from('coupon_history').delete().neq('id', 0),
      _client.from('cash_collections').delete().neq('id', ''),
      _client.from('audit_logs').delete().neq('id', ''),
    ]);
    await _client.from('coupons').delete().neq('id', '');
    await _client.from('wallets').delete().neq('id', '');
    await _client.from('user_sites').delete().neq('id', 0);
    await _client.from('users').delete().neq('id', 'u-sysadmin');
    await _client.from('sites').delete().neq('id', '');
    await _client.from('coupon_profiles').delete().neq('id', '');
    await _client.from('site_prices').delete().neq('id', 0);
    await _client.from('settings').update({
      'low_stock_threshold': 5,
      'telegram_webhook_url': '',
      'whatsapp_notification_enabled': false,
      'two_factor_enabled': false,
    }).eq('id', 1);

    await _client.from('wallets').insert([
      {'id': 'w-system', 'owner_id': 'SYSTEM', 'owner_type': 'SYSTEM', 'balance': 0},
      {'id': 'w-u-sysadmin', 'owner_id': 'u-sysadmin', 'owner_type': 'USER', 'balance': 0}
    ]);
  }
}
