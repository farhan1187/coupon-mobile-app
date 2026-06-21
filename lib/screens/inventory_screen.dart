import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon.dart';
import '../models/coupon_profile.dart';
import '../models/site.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _csvInputController = TextEditingController();
  final _searchController = TextEditingController();
  Site? _selectedSiteForImport;
  bool _isImporting = false;
  String _statusFilter = 'all';

  @override
  void dispose() {
    _csvInputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleImportCoupons(AppStateProvider appState) async {
    final rawText = _csvInputController.text.trim();
    if (rawText.isEmpty) {
      appState.showToast('Please paste some CSV lines first.');
      return;
    }

    setState(() => _isImporting = true);
    final List<String> csvLines = rawText.split('\n');

    try {
      final res = await appState.importCoupons(
        csvLines,
        siteId: _selectedSiteForImport?.id,
      );

      final int count = res['count'] as int? ?? 0;
      final List<String> errors = (res['errors'] as List?)?.cast<String>() ?? [];

      if (mounted) {
        _csvInputController.clear();
        setState(() => _selectedSiteForImport = null);

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                errors.isEmpty ? '✓ Import Completed' : '⚠ Import Completed with Warnings',
                style: TextStyle(
                  color: errors.isEmpty ? Colors.green : Colors.amber[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Successfully imported $count coupons into the system.'),
                    if (errors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Import Warnings / Errors:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.12)),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: errors.length,
                            itemBuilder: (context, idx) => Text(
                              errors[idx],
                              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                )
              ],
            );
          },
        );
      }
    } catch (e) {
      // toast shown by provider
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _confirmDeleteCoupon(BuildContext context, AppStateProvider appState, Coupon coupon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coupon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete coupon "${coupon.code}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(context).pop();
              await appState.deleteCoupon(coupon.id);
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    // Subscription Expiry Guard (for non-all site selection)
    if (appState.selectedSiteId != 'all' && appState.selectedSiteId != 'none') {
      final selectedSite = appState.sites.where((s) => s.id == appState.selectedSiteId).isNotEmpty
          ? appState.sites.firstWhere((s) => s.id == appState.selectedSiteId)
          : null;
      if (selectedSite != null && !selectedSite.isSubscriptionActive) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  border: Border.all(color: Colors.red.withOpacity(0.35), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline, size: 44, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Subscription Expired',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The subscription for ${selectedSite.name} has expired. Stock imports are paused until an Admin renews the subscription.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }

    final showOnlyStockPool = user.role == 'Staff' || user.role == 'Super Staff';

    List<Coupon> filteredCoupons = appState.coupons;
    if (appState.selectedSiteId != 'all') {
      filteredCoupons = filteredCoupons.where((c) => c.siteId == appState.selectedSiteId).toList();
    }

    if (_statusFilter != 'all') {
      filteredCoupons = filteredCoupons.where((c) => c.status == _statusFilter).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filteredCoupons = filteredCoupons.where((c) =>
          c.code.toLowerCase().contains(query) ||
          (c.customerName?.toLowerCase().contains(query) ?? false) ||
          (c.customerPhone?.toLowerCase().contains(query) ?? false)).toList();
    }

    Widget buildStockPool() {
      return RefreshIndicator(
        onRefresh: () => appState.refreshDbState(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appState.couponProfiles.length,
          itemBuilder: (context, index) {
            final profile = appState.couponProfiles[index];
            final totalStock = appState.coupons.where((c) => c.profileId == profile.id && (appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId)).length;
            final available = appState.coupons.where((c) => c.profileId == profile.id && c.status == 'Available' && (appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId)).length;
            final sold = appState.coupons.where((c) => c.profileId == profile.id && c.status == 'Sold' && (appState.selectedSiteId == 'all' || c.siteId == appState.selectedSiteId)).length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.12)),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(profile.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${profile.validityDays} Days', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const Text('Total Pool', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('$totalStock', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Available', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('$available', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Sold', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('$sold', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (showOnlyStockPool) {
      return Scaffold(
        body: buildStockPool(),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Stock Pool'),
            Tab(text: 'Coupons Registry'),
            Tab(text: 'Import CSV'),
          ],
          labelColor: Color(0xFF6366F1),
          indicatorColor: Color(0xFF6366F1),
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Stock levels
            buildStockPool(),

            // Tab 2: Coupons Registry
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search coupons...',
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _statusFilter,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'Available', child: Text('Available')),
                            DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                            DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _statusFilter = val);
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => appState.refreshDbState(),
                        child: filteredCoupons.isEmpty
                            ? const Center(
                                child: Text('No matching coupons found', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: filteredCoupons.length,
                                itemBuilder: (context, index) {
                                  final c = filteredCoupons[index];
                                  final profile = appState.couponProfiles.firstWhere(
                                    (p) => p.id == c.profileId,
                                    orElse: () => CouponProfile(id: '', name: c.profileId, validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
                                  );
                                  final site = appState.sites.firstWhere(
                                    (s) => s.id == c.siteId,
                                    orElse: () => Site(id: '', name: 'Unassigned', location: '', status: '', smsEnabled: true),
                                  );
                                  final isSold = c.status == 'Sold';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                                    ),
                                    elevation: 0,
                                    child: ListTile(
                                      title: Text(
                                        c.code,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text('Profile: ${profile.name}  •  Site: ${site.name}', style: const TextStyle(fontSize: 11)),
                                          if (isSold) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Customer: ${c.customerName?.isNotEmpty == true ? c.customerName : "Walk-in"}  •  By: ${c.soldByUserId}',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ]
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.status == 'Available'
                                                  ? Colors.green.withOpacity(0.1)
                                                  : c.status == 'Sold'
                                                      ? Colors.purple.withOpacity(0.1)
                                                      : Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.status,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: c.status == 'Available'
                                                    ? Colors.green
                                                    : c.status == 'Sold'
                                                        ? Colors.purple
                                                        : Colors.red,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!isSold)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                              onPressed: () => _confirmDeleteCoupon(context, appState, c),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // Tab 3: Import coupons
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Bulk CSV Coupon Importer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Enter CSV lines below. Format: code, profileName, [cost], [salePrice]\nOne entry per line. Example:\nABC-1234, 1 Hour, 1.5, 3.0\nDEF-5678, 1 Hour',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Site>(
                    decoration: const InputDecoration(
                      labelText: 'Assign to Site (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSiteForImport,
                    items: [
                      const DropdownMenuItem<Site>(value: null, child: Text('No Site Allocation (Keep Available)')),
                      ...appState.sites.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedSiteForImport = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _csvInputController,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Pasted CSV Raw Data',
                      hintText: 'code, profile, cost, price',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isImporting ? null : () => _handleImportCoupons(appState),
                    child: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Execute Bulk Import', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
