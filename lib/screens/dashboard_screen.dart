import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon.dart';
import '../models/coupon_profile.dart';
import '../models/site.dart';
import '../models/wallet.dart';
import '../models/user.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: () => appState.refreshDbState(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            Text(
              'Welcome back, ${user.name}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${user.role}  •  Site selection: ${appState.selectedSiteId == "all" ? "All Sites" : appState.selectedSiteId == "none" ? "None" : (appState.sites.firstWhere((s) => s.id == appState.selectedSiteId, orElse: () => Site(id: '', name: 'Selected', location: '', status: '', smsEnabled: false)).name)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Render dashboard depending on role
            _buildDashboardForRole(context, appState, user.role),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardForRole(BuildContext context, AppStateProvider appState, String role) {
    switch (role) {
      case 'Admin':
        return _buildAdminDashboard(context, appState);
      case 'Owner':
        return _buildOwnerDashboard(context, appState);
      case 'Manager':
        return _buildManagerDashboard(context, appState);
      case 'Super Staff':
        return _buildSuperStaffDashboard(context, appState);
      case 'Staff':
        return _buildStaffDashboard(context, appState);
      case 'Accountant':
        return _buildAccountantDashboard(context, appState);
      default:
        return _buildStaffDashboard(context, appState);
    }
  }

  // ── Metrics Grid Helper ────────────────────────────────────────────────────
  Widget _buildMetricGrid({required List<Widget> children, int columns = 2}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 600 ? 3 : columns;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: children,
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bg,
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bg.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bg.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (trend != null) ...[
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: trend.contains('↑') ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      sub,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  // ── Profile Stock Breakdown Widget ─────────────────────────────────────────
  Widget _buildProfileStockBreakdown(BuildContext context, AppStateProvider appState) {
    if (appState.selectedSiteId == 'all') {
      return const SizedBox();
    }

    final site = appState.sites.firstWhere(
      (s) => s.id == appState.selectedSiteId,
      orElse: () => Site(id: '', name: '', location: '', status: '', smsEnabled: false),
    );
    if (site.id.isEmpty) return const SizedBox();

    // Coupons at this site
    final siteCoupons = appState.coupons.where((c) => c.siteId == appState.selectedSiteId).toList();

    // Unique profile IDs at this site
    final profileIds = siteCoupons.map((c) => c.profileId).toSet();
    final profiles = appState.couponProfiles.where((p) => profileIds.contains(p.id)).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 18, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text(
                      'Stock by Profile — ${site.name}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${profiles.length} Profiles',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (profiles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'No coupon stock found for this site',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ...profiles.map((profile) {
                final profCoupons = siteCoupons.where((c) => c.profileId == profile.id).toList();
                final avail = profCoupons.where((c) => c.status == 'Available').length;
                final assigned = profCoupons.where((c) => c.status == 'Assigned').length;
                final sold = profCoupons.where((c) => c.status == 'Sold').length;
                final total = profCoupons.length;
                
                final double availPct = total > 0 ? (avail / total) : 0.0;
                final isLow = avail > 0 && avail < appState.settings.lowStockThreshold;
                final isEmpty = avail == 0;

                final Color barColor = isEmpty 
                    ? Colors.red 
                    : isLow 
                        ? Colors.amber 
                        : Colors.green;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                profile.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              if (isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('OUT', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                                )
                              else if (isLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('LOW', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          Text(
                            '$avail Avail / $total Total',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: availPct,
                          color: barColor,
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Assigned: $assigned', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 12),
                          Text('Sold: $sold', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const Divider(height: 16),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Monthly Sales Chart Component ──────────────────────────────────────────
  Widget _buildMonthlySalesChart(List<Coupon> soldCoupons) {
    final now = DateTime.now();
    // Build last 6 months list
    final List<Map<String, dynamic>> monthData = [];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final monthCoupons = soldCoupons.where((c) {
        if (c.soldAt == null) return false;
        final soldTime = DateTime.parse(c.soldAt!);
        return soldTime.year == d.year && soldTime.month == d.month;
      }).toList();

      final double revenue = monthCoupons.fold(0.0, (sum, c) => sum + c.salePrice);
      final String monthName = _getMonthName(d.month);

      monthData.add({
        'label': monthName,
        'count': monthCoupons.length,
        'revenue': revenue,
      });
    }

    final double maxRevenue = monthData.map((m) => m['revenue'] as double).fold(0.0, max);
    final double maxVal = max(maxRevenue, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.trending_up, size: 18, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  'Monthly Revenue Overview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Custom Bar Chart using Containers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthData.map((m) {
                final double rev = m['revenue'] as double;
                final double pct = rev / maxVal;
                final int height = (pct * 100).round();

                return Column(
                  children: [
                    Text(
                      rev > 0 ? '${rev.toInt()}' : '',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: max(height.toDouble(), 4.0),
                      decoration: BoxDecoration(
                        color: rev > 0 ? const Color(0xFF6366F1) : Colors.grey.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m['label'] as String,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: monthData.map((m) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(m['label'] as String, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      Text('${m['count']} sold', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ── 1. ADMIN DASHBOARD ─────────────────────────────────────────────────────
  Widget _buildAdminDashboard(BuildContext context, AppStateProvider appState) {
    final activeCoupons = appState.coupons.where((c) =>
        appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId).toList();
    final soldCoupons = activeCoupons.where((c) => c.status == 'Sold').toList();

    final int totalCoupons = activeCoupons.length;
    final int available = activeCoupons.where((c) => c.status == 'Available').length;
    final int sold = soldCoupons.length;

    final double totalRevenue = soldCoupons.fold(0.0, (sum, c) => sum + c.salePrice);
    
    // Revenue today
    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    final todaySales = soldCoupons.where((c) => c.soldAt != null && c.soldAt!.substring(0, 10) == todayStr).toList();
    final double todayRevenue = todaySales.fold(0.0, (sum, c) => sum + c.salePrice);

    // Outstanding in staff wallets
    final staffWallets = appState.wallets.where((w) => w.ownerType == 'USER_SALES');
    final double totalPending = staffWallets.fold(0.0, (sum, w) => sum + w.balance);

    final int activeSites = appState.sites.where((s) => s.status == 'Active').length;

    // Top staff list
    final Map<String, double> staffSalesMap = {};
    for (final c in soldCoupons) {
      if (c.soldByUserId != null) {
        staffSalesMap[c.soldByUserId!] = (staffSalesMap[c.soldByUserId!] ?? 0.0) + c.salePrice;
      }
    }
    final sortedStaffKeys = staffSalesMap.keys.toList()
      ..sort((a, b) => staffSalesMap[b]!.compareTo(staffSalesMap[a]!));
    final topStaff = sortedStaffKeys.take(4).map((uid) {
      final userObj = appState.users.firstWhere((u) => u.id == uid, orElse: () => AppUser(id: uid, username: uid, password: '', role: 'Staff', name: uid, twoFAEnabled: false));
      return {
        'name': userObj.name,
        'role': userObj.role,
        'sales': staffSalesMap[uid]!,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'Total Stock', value: '$totalCoupons', sub: 'Coupons in system', icon: Icons.confirmation_number_outlined, color: Colors.blue, bg: Colors.blue),
            _buildStatCard(label: 'Available Stock', value: '$available', sub: '${totalCoupons > 0 ? ((available / totalCoupons) * 100).toStringAsFixed(1) : 0}% of total', icon: Icons.check_circle_outline, color: Colors.green, bg: Colors.green),
            _buildStatCard(label: 'Sold Coupons', value: '$sold', sub: '${totalCoupons > 0 ? ((sold / totalCoupons) * 100).toStringAsFixed(1) : 0}% sell-out', icon: Icons.trending_up, color: Colors.purple, bg: Colors.purple),
            _buildStatCard(label: "Today's Sales", value: '${todayRevenue.toInt()} AED', sub: '${todaySales.length} activations today', icon: Icons.monetization_on_outlined, color: Colors.teal, bg: Colors.teal, trend: '↑ 14%'),
            _buildStatCard(label: 'Pending Cash', value: '${totalPending.toInt()} AED', sub: 'Held by sales staff', icon: Icons.wallet_outlined, color: Colors.amber, bg: Colors.amber),
            _buildStatCard(label: 'Active Sites', value: '$activeSites', sub: 'UAE tenant nodes', icon: Icons.map_outlined, color: Colors.indigo, bg: Colors.indigo),
          ],
        ),
        
        _buildProfileStockBreakdown(context, appState),

        // Custom split row (Top Performers & Site splits)
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Performing Sales Staff',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (topStaff.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No sales records found', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  )
                else
                  ...topStaff.map((staff) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                        child: Text(
                          (staff['name'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(staff['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(staff['role'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Text(
                        '${(staff['sales'] as double).toInt()} AED',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    );
                  })
              ],
            ),
          ),
        ),

        _buildMonthlySalesChart(soldCoupons),
      ],
    );
  }

  // ── 2. OWNER DASHBOARD ─────────────────────────────────────────────────────
  Widget _buildOwnerDashboard(BuildContext context, AppStateProvider appState) {
    final ownerSiteIds = appState.userSites.where((us) => us['userId'] == appState.currentUser!.id).map((us) => us['siteId']!).toSet();
    final ownerSoldCoupons = appState.coupons.where((c) =>
        c.status == 'Sold' &&
        ownerSiteIds.contains(c.siteId) &&
        (appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId)).toList();

    final double totalRevenue = ownerSoldCoupons.fold(0.0, (sum, c) => sum + c.salePrice);
    
    // Revenue today
    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    final todaySales = ownerSoldCoupons.where((c) => c.soldAt != null && c.soldAt!.substring(0, 10) == todayStr).toList();
    final double todayRevenue = todaySales.fold(0.0, (sum, c) => sum + c.salePrice);

    // Revenue this month
    final now = DateTime.now();
    final thisMonthSales = ownerSoldCoupons.where((c) {
      if (c.soldAt == null) return false;
      final d = DateTime.parse(c.soldAt!);
      return d.year == now.year && d.month == now.month;
    }).toList();
    final double thisMonthRevenue = thisMonthSales.fold(0.0, (sum, c) => sum + c.salePrice);

    // Pending cash in wallets
    final staffWallets = appState.wallets.where((w) => w.ownerType == 'USER_SALES');
    final double totalPending = staffWallets.fold(0.0, (sum, w) => sum + w.balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'Total Revenue', value: '${totalRevenue.toInt()} AED', sub: 'Gross site sales', icon: Icons.monetization_on_outlined, color: Colors.green, bg: Colors.green),
            _buildStatCard(label: "Today's Sales", value: '${todayRevenue.toInt()} AED', sub: '${todaySales.length} sold today', icon: Icons.trending_up, color: Colors.blue, bg: Colors.blue),
            _buildStatCard(label: "This Month's Sales", value: '${thisMonthRevenue.toInt()} AED', sub: '${thisMonthSales.length} sold this month', icon: Icons.calendar_month_outlined, color: Colors.purple, bg: Colors.purple),
            _buildStatCard(label: 'Pending Collections', value: '${totalPending.toInt()} AED', sub: 'Held by retail staff', icon: Icons.wallet_outlined, color: Colors.amber, bg: Colors.amber),
          ],
        ),

        _buildProfileStockBreakdown(context, appState),

        _buildMonthlySalesChart(ownerSoldCoupons),
      ],
    );
  }

  // ── 3. MANAGER DASHBOARD ───────────────────────────────────────────────────
  Widget _buildManagerDashboard(BuildContext context, AppStateProvider appState) {
    final managerSiteIds = appState.userSites.where((us) => us['userId'] == appState.currentUser!.id).map((us) => us['siteId']!).toSet();
    final activeCoupons = appState.coupons.where((c) => managerSiteIds.contains(c.siteId) && (appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId)).toList();

    final int totalCoupons = activeCoupons.length;
    final int available = activeCoupons.where((c) => c.status == 'Available').length;
    final int sold = activeCoupons.where((c) => c.status == 'Sold').length;
    final double totalRevenue = activeCoupons.where((c) => c.status == 'Sold').fold(0.0, (sum, c) => sum + c.salePrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'Site Coupons Stock', value: '$totalCoupons', sub: 'Assigned to your sites', icon: Icons.confirmation_number_outlined, color: Colors.blue, bg: Colors.blue),
            _buildStatCard(label: 'Available Stock', value: '$available', sub: 'Ready to be sold', icon: Icons.check_circle_outline, color: Colors.green, bg: Colors.green),
            _buildStatCard(label: 'Sold Coupons', value: '$sold', sub: 'Total site activations', icon: Icons.trending_up, color: Colors.purple, bg: Colors.purple),
            _buildStatCard(label: 'Total Revenue', value: '${totalRevenue.toInt()} AED', sub: 'Gross sales value', icon: Icons.monetization_on_outlined, color: Colors.teal, bg: Colors.teal),
          ],
        ),

        _buildProfileStockBreakdown(context, appState),

        const SizedBox(height: 16),
        // Warning Banner
        if (available < 5)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Critical Low Stock Warning! Your sites have low coupon availability. Please import or request new codes.',
                    style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'All systems active. Coupon stock levels are healthy across your assigned zones.',
                    style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  // ── 4. SUPER STAFF DASHBOARD ───────────────────────────────────────────────
  Widget _buildSuperStaffDashboard(BuildContext context, AppStateProvider appState) {
    final personalWallet = appState.wallets.firstWhere((w) => w.ownerId == appState.currentUser!.id && w.ownerType == 'USER_SALES', orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0));
    final collectionWallet = appState.wallets.firstWhere((w) => w.ownerId == appState.currentUser!.id && w.ownerType == 'USER_COLLECTION', orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0));
    
    final mySiteIds = appState.userSites.where((us) => us['userId'] == appState.currentUser!.id).map((us) => us['siteId']!).toSet();
    final availableSiteStock = appState.coupons.where((c) => mySiteIds.contains(c.siteId) && c.status == 'Available').length;
    final int staffCount = appState.users.where((u) => u.role == 'Staff').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'Personal Sales Wallet', value: '${personalWallet.balance.toInt()} AED', sub: 'From your own sales', icon: Icons.wallet_outlined, color: Colors.blue, bg: Colors.blue),
            _buildStatCard(label: 'Collected Cash Wallet', value: '${collectionWallet.balance.toInt()} AED', sub: 'Collected from staff', icon: Icons.monetization_on_outlined, color: Colors.green, bg: Colors.green),
            _buildStatCard(label: 'Site Pool Stock', value: '$availableSiteStock', sub: 'Available coupons to sell', icon: Icons.confirmation_number_outlined, color: Colors.purple, bg: Colors.purple),
            _buildStatCard(label: 'Active Staff', value: '$staffCount', sub: 'Under your collection', icon: Icons.people_outline, color: Colors.teal, bg: Colors.teal),
          ],
        ),

        _buildProfileStockBreakdown(context, appState),
      ],
    );
  }

  // ── 5. STAFF DASHBOARD ─────────────────────────────────────────────────────
  Widget _buildStaffDashboard(BuildContext context, AppStateProvider appState) {
    final personalWallet = appState.wallets.firstWhere((w) => w.ownerId == appState.currentUser!.id && w.ownerType == 'USER_SALES', orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0));
    
    final mySiteIds = appState.userSites.where((us) => us['userId'] == appState.currentUser!.id).map((us) => us['siteId']!).toSet();
    final availableSiteStock = appState.coupons.where((c) => mySiteIds.contains(c.siteId) && c.status == 'Available').length;

    final todayStr = DateTime.now().toLocal().toString().substring(0, 10);
    final mySalesToday = appState.coupons.where((c) =>
        c.soldByUserId == appState.currentUser!.id &&
        c.status == 'Sold' &&
        c.soldAt != null &&
        c.soldAt!.substring(0, 10) == todayStr).toList();
    final double revenueToday = mySalesToday.fold(0.0, (sum, c) => sum + c.salePrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'My Wallet Balance', value: '${personalWallet.balance.toInt()} AED', sub: 'Awaiting cash collection', icon: Icons.wallet_outlined, color: Colors.green, bg: Colors.green),
            _buildStatCard(label: 'Site Pool Stock', value: '$availableSiteStock', sub: 'Coupons available to sell', icon: Icons.confirmation_number_outlined, color: Colors.blue, bg: Colors.blue),
            _buildStatCard(label: 'Sales Today', value: '${mySalesToday.length}', sub: 'Activated coupons today', icon: Icons.check_circle_outline, color: Colors.purple, bg: Colors.purple),
            _buildStatCard(label: 'Revenue Today', value: '${revenueToday.toInt()} AED', sub: 'Gross value today', icon: Icons.monetization_on_outlined, color: Colors.teal, bg: Colors.teal),
          ],
        ),

        _buildProfileStockBreakdown(context, appState),

        const SizedBox(height: 16),
        // Recent Sales Feed
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Sales Feed (Today)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (mySalesToday.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No sales completed today',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mySalesToday.length,
                    itemBuilder: (context, index) {
                      final sale = mySalesToday[index];
                      final timeStr = sale.soldAt != null ? sale.soldAt!.substring(11, 19) : '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: const Icon(Icons.check, color: Colors.green, size: 18),
                        ),
                        title: Text('Code: ${sale.code}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Customer: ${sale.customerName?.isNotEmpty == true ? sale.customerName : "Walk-in"} • $timeStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: Text('+${sale.salePrice.toInt()} AED', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      );
                    },
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 6. ACCOUNTANT DASHBOARD ────────────────────────────────────────────────
  Widget _buildAccountantDashboard(BuildContext context, AppStateProvider appState) {
    // Balances in Super Staff collection wallets
    final superStaffIds = appState.users.where((u) => u.role == 'Super Staff').map((u) => u.id).toSet();
    final superCollectionWallets = appState.wallets.where((w) => w.ownerType == 'USER_COLLECTION' && superStaffIds.contains(w.ownerId));
    final double superCollected = superCollectionWallets.fold(0.0, (sum, w) => sum + w.balance);

    final int transactionCount = appState.transactions.length;

    final accWallets = appState.wallets.where((w) => w.ownerId == appState.currentUser!.id && w.ownerType == 'ACCOUNTANT_SITE').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMetricGrid(
          children: [
            _buildStatCard(label: 'Pending in Super Staff Wallets', value: '${superCollected.toInt()} AED', sub: 'Ready for accountant collection', icon: Icons.wallet_outlined, color: Colors.amber, bg: Colors.amber),
            _buildStatCard(label: 'Ledger Entries Logged', value: '$transactionCount', sub: 'Total double entries', icon: Icons.book_outlined, color: Colors.blue, bg: Colors.blue),
          ],
        ),

        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site Allocation Cash Balances',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (accWallets.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('No cash wallets allocated', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  )
                else
                  ...accWallets.map((w) {
                    final site = appState.sites.firstWhere((s) => s.id == w.siteId, orElse: () => Site(id: '', name: 'Unknown', location: 'UAE', status: '', smsEnabled: false));
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: const Icon(Icons.account_balance, color: Colors.green, size: 18),
                      ),
                      title: Text('${site.name} Cash Wallet', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('Location: ${site.location}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Text(
                        '${w.balance.toInt()} AED',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    );
                  })
              ],
            ),
          ),
        )
      ],
    );
  }
}
