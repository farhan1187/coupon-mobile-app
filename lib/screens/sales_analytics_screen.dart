import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon.dart';
import '../models/coupon_profile.dart';
import '../models/site.dart';
import '../models/user.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  String _dateMode = 'today'; // 'today', 'month', 'custom'
  DateTime _customFrom = DateTime.now();
  DateTime _customTo = DateTime.now();
  String _selectedSiteId = 'all';

  @override
  void initState() {
    super.initState();
    // Default custom date range is from start of month to today
    final now = DateTime.now();
    _customFrom = DateTime(now.year, now.month, 1);
    _customTo = now;
  }

  Map<String, DateTime> _getRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dateMode == 'today') {
      return {
        'from': today,
        'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      };
    } else if (_dateMode == 'month') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      return {
        'from': startOfMonth,
        'to': today.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      };
    } else {
      return {
        'from': DateTime(_customFrom.year, _customFrom.month, _customFrom.day),
        'to': DateTime(_customTo.year, _customTo.month, _customTo.day, 23, 59, 59),
      };
    }
  }

  bool _isInRange(String? soldAtStr, DateTime from, DateTime to) {
    if (soldAtStr == null) return false;
    final date = DateTime.tryParse(soldAtStr);
    if (date == null) return false;
    return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
        date.isBefore(to.add(const Duration(seconds: 1)));
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _customFrom, end: _customTo),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6366F1),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final currentUser = appState.currentUser;
    if (currentUser == null) return const SizedBox();

    final role = currentUser.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final range = _getRange();
    final fromDate = range['from']!;
    final toDate = range['to']!;

    // 1. Visible site IDs (based on permissions)
    final List<String> visibleSiteIds = appState.getAccessibleSites().map((s) => s.id).toList();

    // Filter based on dropdown selector
    final List<String> filteredSiteIds = _selectedSiteId == 'all'
        ? visibleSiteIds
        : visibleSiteIds.where((id) => id == _selectedSiteId).toList();

    // 2. Compute Site Statistics
    final List<Map<String, dynamic>> siteStats = filteredSiteIds.map((siteId) {
      final site = appState.sites.firstWhere((s) => s.id == siteId, orElse: () => Site(id: siteId, name: siteId, location: '', status: '', smsEnabled: false));
      final soldCoupons = appState.coupons.where((c) => c.status == 'Sold' && c.siteId == siteId).toList();
      final filteredCoupons = soldCoupons.where((c) => _isInRange(c.soldAt, fromDate, toDate)).toList();

      final Map<String, int> profileMap = {};
      for (var c in filteredCoupons) {
        profileMap[c.profileId] = (profileMap[c.profileId] ?? 0) + 1;
      }

      final Map<String, int> sellerMap = {};
      for (var c in filteredCoupons) {
        sellerMap[c.soldByUserId ?? ''] = (sellerMap[c.soldByUserId ?? ''] ?? 0) + 1;
      }

      final double revenue = filteredCoupons.fold(0.0, (sum, c) => sum + (c.salePrice ?? 0.0));
      final double cost = filteredCoupons.fold(0.0, (sum, c) => sum + (c.cost ?? 0.0));

      return {
        'siteId': siteId,
        'site': site,
        'count': filteredCoupons.length,
        'revenue': revenue,
        'cost': cost,
        'profit': revenue - cost,
        'profileMap': profileMap,
        'sellerMap': sellerMap,
        'filtered': filteredCoupons,
      };
    }).toList();

    // Aggregates
    final int totalCount = siteStats.fold(0, (sum, s) => sum + (s['count'] as int));
    final double totalRevenue = siteStats.fold(0.0, (sum, s) => sum + (s['revenue'] as double));
    final double totalCost = siteStats.fold(0.0, (sum, s) => sum + (s['cost'] as double));
    final double totalProfit = totalRevenue - totalCost;
    final int activeSitesCount = siteStats.where((s) => (s['count'] as int) > 0).length;
    final String margin = totalRevenue > 0 ? ((totalProfit / totalRevenue) * 100).toStringAsFixed(1) : '0.0';

    final allFilteredCoupons = siteStats.expand((s) => s['filtered'] as List<Coupon>).toList();

    // Sorted Revenue by Site
    final revenueBySite = siteStats
        .where((s) => (s['count'] as int) > 0)
        .toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    // Sales by Profile totals
    final Map<String, Map<String, dynamic>> profileTotals = {};
    for (var c in allFilteredCoupons) {
      if (!profileTotals.containsKey(c.profileId)) {
        profileTotals[c.profileId] = {'count': 0, 'revenue': 0.0};
      }
      profileTotals[c.profileId]!['count'] = (profileTotals[c.profileId]!['count'] as int) + 1;
      profileTotals[c.profileId]!['revenue'] = (profileTotals[c.profileId]!['revenue'] as double) + (c.salePrice ?? 0.0);
    }

    final salesByProfile = profileTotals.entries.map((entry) {
      final prof = appState.couponProfiles.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => CouponProfile(id: entry.key, name: entry.key, validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
      );
      final count = entry.value['count'] as int;
      final rev = entry.value['revenue'] as double;
      final pct = totalRevenue > 0 ? (rev / totalRevenue * 100).toStringAsFixed(1) : '0.0';

      return {
        'profileId': entry.key,
        'name': prof.name,
        'count': count,
        'revenue': rev,
        'sharePercent': pct,
      };
    }).toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    final String rangeLabel = _dateMode == 'today'
        ? 'Today'
        : _dateMode == 'month'
            ? 'This Month'
            : '${DateFormat('yyyy-MM-dd').format(fromDate)} → ${DateFormat('yyyy-MM-dd').format(toDate)}';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Overall Performance'),
            Tab(text: 'Site Breakdowns'),
          ],
          labelColor: Color(0xFF6366F1),
          indicatorColor: Color(0xFF6366F1),
          labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        body: Column(
          children: [
            // Controls header (Date modes and Site Filter dropdown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date Mode Switches
                    ...['today', 'month', 'custom'].map((mode) {
                      final isSelected = _dateMode == mode;
                      final label = mode == 'today'
                          ? 'Today'
                          : mode == 'month'
                              ? 'This Month'
                              : 'Custom';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(label, style: const TextStyle(fontSize: 11.5)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _dateMode = mode);
                          },
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    // Vertical divider
                    Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(width: 8),

                    // Custom date range edit button
                    if (_dateMode == 'custom') ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: TextButton.icon(
                          onPressed: () => _selectCustomDateRange(context),
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text(
                            '${DateFormat('MM-dd').format(_customFrom)} to ${DateFormat('MM-dd').format(_customTo)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: Colors.indigo.withOpacity(0.08),
                          ),
                        ),
                      ),
                    ],

                    // Site filter dropdown
                    if (visibleSiteIds.length > 1)
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(16),
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSiteId,
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Sites')),
                              ...appState.sites.where((s) => visibleSiteIds.contains(s.id)).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSiteId = val);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Overall Performance
                  RefreshIndicator(
                    onRefresh: () => appState.refreshDbState(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Statistics Cards Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.6,
                            children: [
                              _buildMetricCard(
                                title: 'Total Sales',
                                value: '$totalCount',
                                subtitle: 'coupons sold',
                                color: const Color(0xFF6366F1),
                              ),
                              _buildMetricCard(
                                title: 'Total Revenue',
                                value: '${totalRevenue.toInt()} AED',
                                subtitle: 'gross sales',
                                color: Colors.green,
                              ),
                              _buildMetricCard(
                                title: 'Net Profit',
                                value: '${totalProfit.toInt()} AED',
                                subtitle: 'margin $margin%',
                                color: Colors.purple,
                              ),
                              _buildMetricCard(
                                title: 'Active Sites',
                                value: '$activeSitesCount / ${filteredSiteIds.length}',
                                subtitle: 'had sales',
                                color: Colors.amber[700]!,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Revenue by Site list card
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Revenue by Site', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const Divider(height: 16),
                                  if (revenueBySite.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20.0),
                                      child: Center(child: Text('No site sales in this range.', style: TextStyle(color: Colors.grey, fontSize: 11.5))),
                                    )
                                  else
                                    ...revenueBySite.map((s) {
                                      final double sRev = s['revenue'] as double;
                                      final double sProf = s['profit'] as double;
                                      final String sPct = totalRevenue > 0 ? (sRev / totalRevenue * 100).toStringAsFixed(1) : '0.0';
                                      final Site siteObj = s['site'] as Site;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(siteObj.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                      Text(siteObj.location, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text('${sRev.toInt()} AED', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                                                    if (role != 'Manager' && role != 'Owner')
                                                      Text('Profit: ${sProf.toInt()} AED', style: TextStyle(color: sProf >= 0 ? Colors.green : Colors.red, fontSize: 9.5)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: (double.tryParse(sPct) ?? 0.0) / 100.0,
                                                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[200],
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                                      minHeight: 5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('$sPct%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Sales by Profile list card
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sales by Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const Divider(height: 16),
                                  if (salesByProfile.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20.0),
                                      child: Center(child: Text('No profile sales in this range.', style: TextStyle(color: Colors.grey, fontSize: 11.5))),
                                    )
                                  else
                                    ...salesByProfile.map((p) {
                                      final double pRev = p['revenue'] as double;
                                      final int pCount = p['count'] as int;
                                      final String pPct = p['sharePercent'] as String;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                ),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                                      child: Text('$pCount Sold', style: const TextStyle(fontSize: 9.5, color: Colors.purple, fontWeight: FontWeight.bold)),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text('${pRev.toInt()} AED', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                                                  ],
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: (double.tryParse(pPct) ?? 0.0) / 100.0,
                                                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[200],
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                                                      minHeight: 5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('$pPct%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab 2: Site Breakdowns (Individual Cards)
                  RefreshIndicator(
                    onRefresh: () => appState.refreshDbState(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: siteStats.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final s = siteStats[index];
                        final Site siteObj = s['site'] as Site;
                        final int count = s['count'] as int;
                        final double revenue = s['revenue'] as double;
                        final double profit = s['profit'] as double;
                        final Map<String, int> profileMap = s['profileMap'] as Map<String, int>;
                        final Map<String, int> sellerMap = s['sellerMap'] as Map<String, int>;

                        final profileEntries = profileMap.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final sellerEntries = sellerMap.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        final hasData = count > 0;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(siteObj.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(siteObj.location, style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasData ? Colors.green.withOpacity(0.08) : Colors.grey.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        hasData ? '$count Sold' : 'No Sales',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: hasData ? Colors.green : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // Metrics for this site
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                        child: Column(
                                          children: [
                                            const Text('Qty', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            const SizedBox(height: 2),
                                            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                        child: Column(
                                          children: [
                                            const Text('Revenue', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            const SizedBox(height: 2),
                                            Text('${revenue.toInt()} AED', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (role != 'Manager' && role != 'Owner') ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            children: [
                                              const Text('Profit', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                              const SizedBox(height: 2),
                                              Text('${profit.toInt()} AED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: profit >= 0 ? Colors.green : Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),

                                if (hasData) ...[
                                  const SizedBox(height: 16),
                                  // Profile break down
                                  const Text('PROFILES SOLD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  ...profileEntries.map((e) {
                                    final prof = appState.couponProfiles.firstWhere(
                                      (p) => p.id == e.key,
                                      orElse: () => CouponProfile(id: e.key, name: e.key, validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
                                    );
                                    final double profPrice = appState.sitePrices.firstWhere(
                                          (sp) => sp['siteId'] == siteObj.id && sp['profileId'] == e.key,
                                          orElse: () => {'salePrice': prof.salePrice},
                                        )['salePrice'] as double;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(prof.name, style: const TextStyle(fontSize: 11.5)),
                                          Text(
                                            '${e.value} sold (${(profPrice * e.value).toInt()} AED)',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  // Seller break down
                                  if (sellerEntries.isNotEmpty && ['Admin', 'Owner', 'Manager', 'Accountant'].contains(role)) ...[
                                    const SizedBox(height: 12),
                                    const Text('SALES BY STAFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: sellerEntries.map((e) {
                                        final seller = appState.users.firstWhere(
                                          (u) => u.id == e.key,
                                          orElse: () => AppUser(id: e.key, username: e.key, password: '', role: '', name: e.key, twoFAEnabled: false),
                                        );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${seller.name} (${e.value})',
                                            style: const TextStyle(fontSize: 10.5),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  ]
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required Color color}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
