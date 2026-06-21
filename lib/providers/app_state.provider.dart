import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/site.dart';
import '../models/coupon_profile.dart';
import '../models/coupon.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/audit_log.dart';
import '../models/settings.dart';
import '../models/cash_collection.dart';
import '../services/supabase_service.dart';

class AppNotification {
  final String id;
  final String timestamp;
  final String type; // 'WARNING' or 'LOG'
  final String message;
  final String icon;
  final String color; // hex representation or label
  final String bg; // hex representation or label

  AppNotification({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.message,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

class AppStateProvider extends ChangeNotifier {
  final SupabaseService _dbService = SupabaseService();

  // State Variables
  Map<String, dynamic> _db = {
    'sites': <Site>[],
    'couponProfiles': <CouponProfile>[],
    'users': <AppUser>[],
    'userSites': <Map<String, String>>[],
    'sitePrices': <Map<String, dynamic>>[],
    'coupons': <Coupon>[],
    'wallets': <Wallet>[],
    'transactions': <AppTransaction>[],
    'auditLogs': <AuditLog>[],
    'settings': SystemSettings(
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
    ),
    'cashCollections': <CashCollection>[],
  };

  bool _appLoading = true;
  AppUser? _currentUser;
  String _selectedSiteId = 'all';
  String _searchQuery = '';
  String _theme = 'light';
  List<AppNotification> _notifications = [];
  bool _unreadNotifications = false;
  String? _toastMessage;

  // Getters
  Map<String, dynamic> get db => _db;
  bool get appLoading => _appLoading;
  AppUser? get currentUser => _currentUser;
  String get selectedSiteId => _selectedSiteId;
  String get searchQuery => _searchQuery;
  String get theme => _theme;
  List<AppNotification> get notifications => _notifications;
  bool get unreadNotifications => _unreadNotifications;
  String? get toastMessage => _toastMessage;

  List<Site> get sites => _db['sites'] as List<Site>;
  List<CouponProfile> get couponProfiles => _db['couponProfiles'] as List<CouponProfile>;
  List<AppUser> get users => _db['users'] as List<AppUser>;
  List<Map<String, String>> get userSites => (_db['userSites'] as List).cast<Map<String, String>>();
  List<Map<String, dynamic>> get sitePrices => (_db['sitePrices'] as List).cast<Map<String, dynamic>>();
  List<Coupon> get coupons => _db['coupons'] as List<Coupon>;
  List<Wallet> get wallets => _db['wallets'] as List<Wallet>;
  List<AppTransaction> get transactions => _db['transactions'] as List<AppTransaction>;
  List<AuditLog> get auditLogs => _db['auditLogs'] as List<AuditLog>;
  SystemSettings get settings => _db['settings'] as SystemSettings;
  List<CashCollection> get cashCollections => _db['cashCollections'] as List<CashCollection>;

  // Constants
  static const List<String> globalRoles = ['Admin'];

  AppStateProvider() {
    init();
  }

  // ── Initialization ─────────────────────────────────────────────────────────
  Future<void> init() async {
    _appLoading = true;
    notifyListeners();

    try {
      final freshDb = await refreshDbState();
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('coupon_session_user');
      
      if (savedUserJson != null && freshDb != null) {
        final Map<String, dynamic> parsed = json.decode(savedUserJson);
        final user = await _dbService.findUser(parsed['username'] as String);

        if (user != null && user.password == parsed['password']) {
          _currentUser = user;
          
          if (!globalRoles.contains(user.role)) {
            final assignedSites = userSites
                .where((us) => us['userId'] == user.id)
                .map((us) => us['siteId']!)
                .toList();
            _selectedSiteId = assignedSites.isNotEmpty ? assignedSites[0] : 'none';
          } else {
            _selectedSiteId = 'all';
          }
        } else {
          prefs.remove('coupon_session_user');
        }
      }
    } catch (e) {
      showToast('Database connection error');
    } finally {
      _appLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> refreshDbState() async {
    try {
      final freshDb = await _dbService.getDb();
      _db = freshDb;
      _updateNotifications();
      notifyListeners();
      return freshDb;
    } catch (e) {
      showToast('Database sync failed');
      return null;
    }
  }

  // Toast
  void showToast(String message) {
    _toastMessage = message;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      _toastMessage = null;
      notifyListeners();
    });
  }

  void setSelectedSiteId(String id) {
    _selectedSiteId = id;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleTheme() async {
    _theme = _theme == 'light' ? 'dark' : 'light';
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('coupon_theme', _theme);
    notifyListeners();
  }

  void clearUnreadNotifications() {
    _unreadNotifications = false;
    notifyListeners();
  }

  // ── Access Scoping ─────────────────────────────────────────────────────────
  List<Site> getAccessibleSites() {
    if (_currentUser == null) return [];
    if (globalRoles.contains(_currentUser!.role)) return sites;
    
    final assignedIds = userSites
        .where((us) => us['userId'] == _currentUser!.id)
        .map((us) => us['siteId'])
        .toSet();
    return sites.where((s) => assignedIds.contains(s.id)).toList();
  }

  // ── Authentication ─────────────────────────────────────────────────────────
  Future<bool> loginUser(String username, String password) async {
    try {
      final user = await _dbService.findUser(username);
      if (user != null && user.password == password) {
        final freshDb = await refreshDbState();
        if (freshDb != null) {
          if (globalRoles.contains(user.role)) {
            _selectedSiteId = 'all';
          } else {
            final assignedSites = userSites
                .where((us) => us['userId'] == user.id)
                .map((us) => us['siteId']!)
                .toList();
            _selectedSiteId = assignedSites.isNotEmpty ? assignedSites[0] : 'none';
          }

          _currentUser = user;
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('coupon_session_user', json.encode(user.toJson()));
          await _dbService.logAction(user.id, 'LOGIN', 'Logged in as ${user.role} via mobile');
          showToast('Welcome back, ${user.name}!');
          return true;
        }
      }
    } catch (e) {
      showToast('Login failed: Database error');
    }
    return false;
  }

  Future<void> logoutUser() async {
    if (_currentUser != null) {
      await _dbService.logAction(_currentUser!.id, 'LOGOUT', 'Logged out');
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('coupon_session_user');
      _currentUser = null;
      _selectedSiteId = 'all';
      await refreshDbState();
      notifyListeners();
    }
  }

  // ── Notifications Engine ───────────────────────────────────────────────────
  void _updateNotifications() {
    if (_currentUser == null) {
      _notifications = [];
      return;
    }

    final role = _currentUser!.role;
    final threshold = settings.lowStockThreshold;

    final List<AppNotification> alerts = [];

    final List<String> userSiteIds = globalRoles.contains(role)
        ? sites.map((s) => s.id).toList()
        : userSites.where((us) => us['userId'] == _currentUser!.id).map((us) => us['siteId']!).toList();

    // 0. Subscription expiry alerts (site scoped)
    for (final siteId in userSiteIds) {
      final site = sites.firstWhere(
        (s) => s.id == siteId,
        orElse: () => Site(id: '', name: '', location: '', status: '', smsEnabled: false),
      );
      if (site.id.isEmpty || site.subscriptionExpiry == null) continue;
      final expiry = DateTime.tryParse(site.subscriptionExpiry!);
      if (expiry == null) continue;
      final msLeft = expiry.difference(DateTime.now()).inMilliseconds;
      if (msLeft <= 0) {
        alerts.add(AppNotification(
          id: 'sub-expired-${site.id}',
          timestamp: DateTime.now().toIso8601String(),
          type: 'WARNING',
          message: 'Subscription expired for ${site.name}. Coupon sales and imports are paused until an Admin renews it.',
          icon: 'warning',
          color: 'red',
          bg: 'red_light',
        ));
      } else if (msLeft <= 3 * 24 * 60 * 60 * 1000) {
        final daysLeft = (msLeft / (24 * 60 * 60 * 1000)).ceil().clamp(1, 3);
        alerts.add(AppNotification(
          id: 'sub-expiring-${site.id}',
          timestamp: DateTime.now().toIso8601String(),
          type: 'WARNING',
          message: 'Subscription for ${site.name} expires in $daysLeft day${daysLeft == 1 ? '' : 's'}.',
          icon: 'warning',
          color: 'orange',
          bg: 'orange_light',
        ));
      }
    }

    // 1. Low stock alerts (site & profile scoped)
    for (final siteId in userSiteIds) {
      final site = sites.firstWhere((s) => s.id == siteId, orElse: () => Site(id: '', name: '', location: '', status: '', smsEnabled: false));
      if (site.id.isEmpty) continue;

      for (final profile in couponProfiles) {
        final siteAssignedCount = coupons.where((c) =>
            c.profileId == profile.id &&
            c.siteId == siteId &&
            (c.status == 'Assigned' || c.status == 'Available')).length;

        if (siteAssignedCount > 0 && siteAssignedCount < threshold) {
          alerts.add(AppNotification(
            id: 'warn-$siteId-${profile.id}',
            timestamp: DateTime.now().toIso8601String(),
            type: 'WARNING',
            message: 'Low stock: ${profile.name} at ${site.name} has only $siteAssignedCount unit(s) left.',
            icon: 'warning',
            color: 'orange',
            bg: 'orange_light',
          ));
        }
      }
    }

    // 2. Recent Audit Logs
    final List<String>? visibleRoles = _getVisibleRolesForLogs(role);
    const excludedActions = ['LOGIN', 'LOGOUT', 'SALE', 'COUPON_SALE'];

    final filteredLogs = auditLogs.where((log) {
      if (excludedActions.any((ex) => log.action.contains(ex))) return false;
      if (visibleRoles != null) {
        final logUser = users.firstWhere((u) => u.id == log.userId, orElse: () => AppUser(id: '', username: '', password: '', role: '', name: '', twoFAEnabled: false));
        if (log.userId != _currentUser!.id && !visibleRoles.contains(logUser.role)) return false;
      }
      return true;
    }).take(8).toList();

    final List<AppNotification> logsAlerts = filteredLogs.map((log) {
      String icon = 'bell';
      String color = 'blue';
      String bg = 'blue_light';

      if (log.action.contains('COLLECTION')) {
        icon = 'currency_exchange';
        color = 'purple';
        bg = 'purple_light';
      } else if (log.action.contains('REVERSAL')) {
        icon = 'settings_backup_restore';
        color = 'red';
        bg = 'red_light';
      } else if (log.action.contains('ASSIGN')) {
        icon = 'link';
        color = 'blue';
        bg = 'blue_light';
      }

      final userObj = users.firstWhere((u) => u.id == log.userId, orElse: () => AppUser(id: '', username: '', password: '', role: '', name: '', twoFAEnabled: false));
      final userName = userObj.name.isNotEmpty ? userObj.name : log.userId;

      return AppNotification(
        id: log.id,
        timestamp: log.timestamp,
        type: 'LOG',
        message: '$userName: ${log.details}',
        icon: icon,
        color: color,
        bg: bg,
      );
    }).toList();

    _notifications = [...alerts, ...logsAlerts];
    if (alerts.isNotEmpty) {
      _unreadNotifications = true;
    }
  }

  List<String>? _getVisibleRolesForLogs(String role) {
    switch (role) {
      case 'Admin':
        return null;
      case 'Owner':
        return ['Owner', 'Manager', 'Accountant'];
      case 'Manager':
        return ['Manager', 'Staff', 'Super Staff'];
      case 'Super Staff':
        return ['Super Staff', 'Staff'];
      case 'Staff':
        return ['Staff'];
      case 'Accountant':
        return ['Accountant'];
      default:
        return [role];
    }
  }

  // ── Database Operations Wrappers ───────────────────────────────────────────
  Future<Map<String, dynamic>> sellCoupon({
    required String profileId,
    required String customerName,
    required String customerPhone,
    required String remarks,
  }) async {
    if (_currentUser == null || _selectedSiteId == 'all' || _selectedSiteId == 'none') {
      throw Exception('Invalid site selected');
    }

    try {
      final res = await _dbService.sellCoupon(
        siteId: _selectedSiteId,
        profileId: profileId,
        soldByUserId: _currentUser!.id,
        customerName: customerName,
        customerPhone: customerPhone,
        remarks: remarks,
      );
      refreshDbState(); // Fetch updates asynchronously
      showToast('Coupon sold successfully!');
      return res;
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> collectCashFromStaff({
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    if (_currentUser == null) return;
    try {
      await _dbService.collectCashFromStaff(
        collectedByUserId: _currentUser!.id,
        collectedFromUserId: collectedFromUserId,
        amount: amount,
        siteId: siteId,
        remarks: remarks,
      );
      await refreshDbState();
      showToast('Collected $amount AED!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> collectCashFromSuperStaff({
    required String collectedFromUserId,
    required List<Map<String, dynamic>> splits,
    required String remarks,
  }) async {
    if (_currentUser == null) return;
    try {
      await _dbService.collectCashFromSuperStaff(
        collectedByUserId: _currentUser!.id,
        collectedFromUserId: collectedFromUserId,
        splits: splits,
        remarks: remarks,
      );
      await refreshDbState();
      showToast('Super Staff collection complete!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> collectCashFromManager({
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    if (_currentUser == null) return;
    try {
      await _dbService.collectCashFromManager(
        collectedByUserId: _currentUser!.id,
        collectedFromUserId: collectedFromUserId,
        amount: amount,
        siteId: siteId,
        remarks: remarks,
      );
      await refreshDbState();
      showToast('Collected $amount AED from Manager!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> collectCashFromOwner({
    required String collectedFromUserId,
    required double amount,
    String? siteId,
    required String remarks,
  }) async {
    if (_currentUser == null) return;
    try {
      await _dbService.collectCashFromOwner(
        collectedByUserId: _currentUser!.id,
        collectedFromUserId: collectedFromUserId,
        amount: amount,
        siteId: siteId,
        remarks: remarks,
      );
      await refreshDbState();
      showToast('Collected $amount AED from Owner!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> reverseTransaction(String transactionId, String reason) async {
    if (_currentUser == null) return;
    try {
      await _dbService.reverseTransaction(transactionId, _currentUser!.id, reason);
      await refreshDbState();
      showToast('Transaction reversed!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> walletAdjustment(String walletId, double amount, String remarks) async {
    if (_currentUser == null) return;
    try {
      await _dbService.walletAdjustment(walletId, amount, remarks, _currentUser!.id);
      await refreshDbState();
      showToast('Wallet adjusted by $amount AED!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> updateSettings(SystemSettings newSettings) async {
    try {
      await _dbService.updateSettings(newSettings, _currentUser?.id ?? 'admin');
      await refreshDbState();
      showToast('Settings saved');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> addSite(String name, String location) async {
    if (_currentUser == null) return;
    try {
      await _dbService.addSite(name, location, _currentUser!.id);
      await refreshDbState();
      showToast('Site $name created');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> deleteSite(String siteId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.deleteSite(siteId, _currentUser!.id);
      await refreshDbState();
      showToast('Site deleted');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> addCouponProfile(CouponProfile profile) async {
    if (_currentUser == null) return;
    try {
      await _dbService.addCouponProfile(profile, _currentUser!.id);
      await refreshDbState();
      showToast('Profile ${profile.name} created');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> deleteCouponProfile(String profileId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.deleteCouponProfile(profileId, _currentUser!.id);
      await refreshDbState();
      showToast('Profile deleted');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> addUser(AppUser user, List<String> siteIds) async {
    if (_currentUser == null) return;
    try {
      await _dbService.addUser(user, siteIds, _currentUser!.id);
      await refreshDbState();
      showToast('User ${user.username} created');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> deleteUser(String userId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.deleteUser(userId, _currentUser!.id);
      await refreshDbState();
      showToast('User deleted');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> linkUserToSite(String userId, String siteId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.linkUserToSite(userId, siteId, _currentUser!.id);
      await refreshDbState();
      showToast('User linked to site');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> unlinkUserFromSite(String userId, String siteId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.unlinkUserFromSite(userId, siteId, _currentUser!.id);
      await refreshDbState();
      showToast('User unlinked');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> updateSitePrice(String siteId, String profileId, double salePrice, double costPrice) async {
    if (_currentUser == null) return;
    try {
      await _dbService.updateSitePrice(siteId, profileId, salePrice, costPrice, _currentUser!.id);
      await refreshDbState();
      showToast('Price updated!');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> assignProfileToSite(String siteId, String profileId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.assignProfileToSite(siteId, profileId, _currentUser!.id);
      await refreshDbState();
      showToast('Profile assigned to site');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> unassignProfileFromSite(String siteId, String profileId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.unassignProfileFromSite(siteId, profileId, _currentUser!.id);
      await refreshDbState();
      showToast('Profile unassigned');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> updateSiteSmsEnabled(String siteId, bool enabled) async {
    if (_currentUser == null) return;
    try {
      await _dbService.updateSiteSmsEnabled(siteId, enabled, _currentUser!.id);
      await refreshDbState();
      showToast('SMS ${enabled ? "enabled" : "disabled"} for site');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> importCoupons(List<String> csvLines, {String? siteId}) async {
    if (_currentUser == null) throw Exception('User not logged in');
    try {
      final res = await _dbService.importCoupons(csvLines: csvLines, importedByUserId: _currentUser!.id, siteId: siteId);
      await refreshDbState();
      showToast('Imported ${res["count"]} coupons successfully');
      return res;
    } catch (e) {
      showToast('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> deleteCoupon(String couponId) async {
    if (_currentUser == null) return;
    try {
      await _dbService.deleteCoupon(couponId, _currentUser!.id);
      await refreshDbState();
      showToast('Coupon deleted');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> bulkDeleteCoupons(List<String> couponIds) async {
    if (_currentUser == null) return;
    try {
      await _dbService.bulkDeleteCoupons(couponIds, _currentUser!.id);
      await refreshDbState();
      showToast('Bulk coupon deletion completed');
    } catch (e) {
      showToast('Error: ${e.toString()}');
    }
  }

  Future<void> resetDatabase() async {
    try {
      await _dbService.resetDb();
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('coupon_session_user');
      _currentUser = null;
      _selectedSiteId = 'all';
      await refreshDbState();
      showToast('Database reset successfully');
    } catch (e) {
      showToast('Reset failed: ${e.toString()}');
    }
  }
}
