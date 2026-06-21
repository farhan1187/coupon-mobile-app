import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon.dart';
import '../models/coupon_profile.dart';
import '../models/user.dart';
import '../models/site.dart';

class SalesLogScreen extends StatefulWidget {
  const SalesLogScreen({super.key});

  @override
  State<SalesLogScreen> createState() => _SalesLogScreenState();
}

class _SalesLogScreenState extends State<SalesLogScreen> {
  final _searchController = TextEditingController();
  String _selectedSiteId = 'all';
  String _selectedProfileId = 'all';
  String _selectedSellerId = 'all';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedSiteId = 'all';
      _selectedProfileId = 'all';
      _selectedSellerId = 'all';
      _dateFrom = null;
      _dateTo = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
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

    // 1. Determine visible site IDs
    final List<String> visibleSiteIds = appState.getAccessibleSites().map((s) => s.id).toList();

    // 2. Base sales: Sold coupons within visible sites
    final List<Coupon> baseSales = appState.coupons
        .where((c) => c.status == 'Sold' && visibleSiteIds.contains(c.siteId))
        .toList();

    // 3. Dropdown data
    final dropdownSites = appState.sites.where((s) => visibleSiteIds.contains(s.id)).toList();

    final Set<String> activeProfileIds = baseSales.map((c) => c.profileId).toSet();
    final dropdownProfiles = appState.couponProfiles.where((p) => activeProfileIds.contains(p.id)).toList();

    final Set<String> visibleSellerIds = appState.userSites
        .where((us) => visibleSiteIds.contains(us['siteId']))
        .map((us) => us['userId']!)
        .toSet();
    final dropdownSellers = appState.users.where((u) => visibleSellerIds.contains(u.id)).toList();

    // 4. Filtering logic
    List<Coupon> filteredSales = baseSales.where((c) {
      // Site filter
      if (_selectedSiteId != 'all' && c.siteId != _selectedSiteId) return false;
      // Profile filter
      if (_selectedProfileId != 'all' && c.profileId != _selectedProfileId) return false;
      // Seller filter
      if (_selectedSellerId != 'all' && c.soldByUserId != _selectedSellerId) return false;

      // Date from
      if (_dateFrom != null && c.soldAt != null) {
        final soldDate = DateTime.tryParse(c.soldAt!)?.toLocal();
        if (soldDate != null) {
          final compareDate = DateTime(soldDate.year, soldDate.month, soldDate.day);
          if (compareDate.isBefore(_dateFrom!)) return false;
        }
      }

      // Date to
      if (_dateTo != null && c.soldAt != null) {
        final soldDate = DateTime.tryParse(c.soldAt!)?.toLocal();
        if (soldDate != null) {
          final compareDate = DateTime(soldDate.year, soldDate.month, soldDate.day);
          if (compareDate.isAfter(_dateTo!)) return false;
        }
      }

      // Search text filter
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final codeMatch = c.code.toLowerCase().contains(q);
        final nameMatch = c.customerName?.toLowerCase().contains(q) ?? false;
        final phoneMatch = c.customerPhone?.toLowerCase().contains(q) ?? false;
        if (!codeMatch && !nameMatch && !phoneMatch) return false;
      }

      return true;
    }).toList();

    // Sort by soldAt descending
    filteredSales.sort((a, b) {
      final aSoldAt = a.soldAt ?? '';
      final bSoldAt = b.soldAt ?? '';
      return bSoldAt.compareTo(aSoldAt);
    });

    // Stats calculations
    final showRevenue = role != 'Staff' && role != 'Super Staff';
    final double totalRevenue = filteredSales.fold(0.0, (sum, c) => sum + (c.salePrice ?? 0.0));

    final hasActiveFilters = _selectedSiteId != 'all' ||
        _selectedProfileId != 'all' ||
        _selectedSellerId != 'all' ||
        _dateFrom != null ||
        _dateTo != null ||
        _searchController.text.trim().isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => appState.refreshDbState(),
        child: Column(
          children: [
            // Filter drawer or search bar header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search coupon, name or phone...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  
                  // Horizontal list of quick filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Clear Filters Button
                        if (hasActiveFilters) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              avatar: const Icon(Icons.filter_list_off, size: 14, color: Colors.redAccent),
                              label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              backgroundColor: Colors.redAccent.withOpacity(0.08),
                              side: const BorderSide(color: Colors.redAccent, width: 0.5),
                              onPressed: _clearFilters,
                            ),
                          ),
                        ],

                        // Site filter dropdown
                        if (dropdownSites.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Container(
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
                                    ...dropdownSites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSiteId = val);
                                  },
                                ),
                              ),
                            ),
                          ),

                        // Profile filter dropdown
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(16),
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedProfileId,
                                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: [
                                  const DropdownMenuItem(value: 'all', child: Text('All Profiles')),
                                  ...dropdownProfiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedProfileId = val);
                                },
                              ),
                            ),
                          ),
                        ),

                        // Seller Filter
                        if (dropdownSellers.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(16),
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSellerId,
                                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black),
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('All Sellers')),
                                    ...dropdownSellers.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSellerId = val);
                                  },
                                ),
                              ),
                            ),
                          ),

                        // From Date
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              _dateFrom == null ? 'From Date' : DateFormat('yyyy-MM-dd').format(_dateFrom!),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _dateFrom != null,
                            onSelected: (_) => _selectDate(context, true),
                          ),
                        ),

                        // To Date
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              _dateTo == null ? 'To Date' : DateFormat('yyyy-MM-dd').format(_dateTo!),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _dateTo != null,
                            onSelected: (_) => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // Summary metrics bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredSales.length} sales found',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  if (showRevenue)
                    Text(
                      'Revenue: ${totalRevenue.toInt()} AED',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                ],
              ),
            ),

            // Log Results
            Expanded(
              child: filteredSales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text('No matching sales logs found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          if (hasActiveFilters) ...[
                            const SizedBox(height: 8),
                            TextButton(onPressed: _clearFilters, child: const Text('Reset Filters', style: TextStyle(fontSize: 12))),
                          ]
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredSales.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final c = filteredSales[index];
                        final profile = appState.couponProfiles.firstWhere(
                          (p) => p.id == c.profileId,
                          orElse: () => CouponProfile(id: c.profileId, name: c.profileId, validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
                        );
                        final site = appState.sites.firstWhere(
                          (s) => s.id == c.siteId,
                          orElse: () => Site(id: '', name: '—', location: '', status: '', smsEnabled: false),
                        );
                        final seller = appState.users.firstWhere(
                          (u) => u.id == c.soldByUserId,
                          orElse: () => AppUser(id: '', username: 'Unknown', password: '', role: '', name: 'Unknown', twoFAEnabled: false),
                        );

                        final date = c.soldAt != null ? DateTime.tryParse(c.soldAt!)?.toLocal() : null;
                        final formattedDate = date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : '—';

                        final remarksStr = (() {
                          if (c.history.isEmpty) return '';
                          try {
                            final soldHistory = c.history.firstWhere((h) => h.action == 'SOLD');
                            final details = soldHistory.details;
                            final parts = details.split('AED.');
                            if (parts.length > 1) return parts[1].trim();
                            return details;
                          } catch (_) {
                            return '';
                          }
                        })();

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_outlined, size: 18, color: Color(0xFF6366F1)),
                            ),
                            title: Text(
                              c.code,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, fontFamily: 'monospace'),
                            ),
                            subtitle: Text(
                              '${profile.name} • ${site.name}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (showRevenue)
                                  Text(
                                    '${c.salePrice?.toInt()} AED',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate.split(' ')[0],
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                )
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Table(
                                  columnWidths: const {
                                    0: FixedColumnWidth(100),
                                    1: FlexColumnWidth(),
                                  },
                                  children: [
                                    TableRow(children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text('Sold By:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text('${seller.name} (${seller.role})', style: const TextStyle(fontSize: 12)),
                                      ),
                                    ]),
                                    TableRow(children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text('Customer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text(c.customerName?.isNotEmpty == true ? c.customerName! : '—', style: const TextStyle(fontSize: 12)),
                                      ),
                                    ]),
                                    TableRow(children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text('Mobile:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text(c.customerPhone?.isNotEmpty == true ? c.customerPhone! : '—', style: const TextStyle(fontSize: 12)),
                                      ),
                                    ]),
                                    TableRow(children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text('Sold At:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text(formattedDate, style: const TextStyle(fontSize: 12)),
                                      ),
                                    ]),
                                    if (remarksStr.isNotEmpty)
                                      TableRow(children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4.0),
                                          child: Text('Remarks:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Text(remarksStr, style: const TextStyle(fontSize: 12)),
                                        ),
                                      ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
