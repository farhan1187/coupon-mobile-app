import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/wallet.dart';
import '../models/user.dart';
import '../models/site.dart';

class WalletsScreen extends StatefulWidget {
  final int initialTab;
  const WalletsScreen({super.key, this.initialTab = 0});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final _searchController = TextEditingController();
  final _adjustFormKey = GlobalKey<FormState>();
  final _adjustAmountController = TextEditingController();
  final _adjustRemarksController = TextEditingController();

  Wallet? _adjustTargetWallet;
  bool _isAdjusting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _adjustAmountController.dispose();
    _adjustRemarksController.dispose();
    super.dispose();
  }

  void _handleAdjustBalance(AppStateProvider appState) async {
    if (!_adjustFormKey.currentState!.validate() || _adjustTargetWallet == null) return;
    setState(() => _isAdjusting = true);

    final double amt = double.parse(_adjustAmountController.text.trim());
    final String remarks = _adjustRemarksController.text.trim();

    try {
      await appState.walletAdjustment(_adjustTargetWallet!.id, amt, remarks);
      _adjustAmountController.clear();
      _adjustRemarksController.clear();
      setState(() => _adjustTargetWallet = null);
    } catch (e) {
      // handled by provider toast
    } finally {
      setState(() => _isAdjusting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    final isAdmin = user.role == 'Admin';

    // 1. Wallets filter
    List<Wallet> walletsList = appState.wallets;
    if (['Staff', 'Super Staff'].contains(user.role)) {
      walletsList = walletsList.where((w) => w.ownerId == user.id).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      walletsList = walletsList.where((w) {
        final u = appState.users.firstWhere(
          (usr) => usr.id == w.ownerId,
          orElse: () => AppUser(id: '', username: '', password: '', role: '', name: '', twoFAEnabled: false),
        );
        return u.name.toLowerCase().contains(query) || w.id.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Cash In Hand calculations (sorted list of staff who have wallet balance > 0)
    final List<String> visibleSiteIds = (user.role == 'Admin' || user.role == 'Owner' || user.role == 'Accountant')
        ? appState.sites.map((s) => s.id).toList()
        : appState.userSites.where((us) => us['userId'] == user.id).map((us) => us['siteId']!).toList();

    final List<String> visibleRoles = [];
    if (user.role == 'Super Staff') visibleRoles.addAll(['Staff']);
    else if (user.role == 'Manager') visibleRoles.addAll(['Staff', 'Super Staff']);
    else if (user.role == 'Owner') visibleRoles.addAll(['Staff', 'Super Staff', 'Manager']);
    else if (user.role == 'Accountant') visibleRoles.addAll(['Staff', 'Super Staff', 'Manager', 'Owner']);
    else if (user.role == 'Admin') visibleRoles.addAll(['Staff', 'Super Staff', 'Manager', 'Owner', 'Accountant']);

    final Map<String, Map<String, dynamic>> cashInHandMap = {};
    for (final w in appState.wallets) {
      if (w.ownerType == null || !w.ownerType.startsWith('USER')) continue;
      if (w.ownerId == 'SYSTEM') continue;
      if (w.siteId != null && !visibleSiteIds.contains(w.siteId)) continue;
      if (w.balance <= 0) continue;

      final staff = appState.users.firstWhere(
        (u) => u.id == w.ownerId,
        orElse: () => AppUser(id: '', username: '', password: '', role: '', name: '', twoFAEnabled: false),
      );
      if (staff.id.isEmpty || !visibleRoles.contains(staff.role)) continue;

      final key = w.ownerId;
      if (!cashInHandMap.containsKey(key)) {
        cashInHandMap[key] = {
          'user': staff,
          'totalBalance': 0.0,
          'wallets': <Wallet>[],
        };
      }
      cashInHandMap[key]!['totalBalance'] = (cashInHandMap[key]!['totalBalance'] as double) + w.balance;
      (cashInHandMap[key]!['wallets'] as List<Wallet>).add(w);
    }

    final cashInHandEntries = cashInHandMap.values.toList()
      ..sort((a, b) => (b['totalBalance'] as double).compareTo(a['totalBalance'] as double));

    final double totalCashInHand = cashInHandEntries.fold(0.0, (sum, entry) => sum + (entry['totalBalance'] as double));
    final double highestBalance = cashInHandEntries.isNotEmpty ? cashInHandEntries[0]['totalBalance'] as double : 0.0;
    final String highestName = cashInHandEntries.isNotEmpty ? (cashInHandEntries[0]['user'] as AppUser).name : 'None';

    final rankColors = [const Color(0xFFF59E0B), const Color(0xFF9CA3AF), const Color(0xFFB45309)];

    return DefaultTabController(
      initialIndex: widget.initialTab,
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Wallets Overview'),
            Tab(text: 'Cash In Hand Report'),
          ],
          labelColor: Color(0xFF6366F1),
          indicatorColor: Color(0xFF6366F1),
          labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Wallets list + adjustments
            RefreshIndicator(
              onRefresh: () => appState.refreshDbState(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Adjustment Form for Admin
                    if (isAdmin) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _adjustFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Balance Adjustments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<Wallet>(
                                  decoration: const InputDecoration(labelText: 'Target Wallet *', border: OutlineInputBorder()),
                                  value: _adjustTargetWallet,
                                  items: appState.wallets.map((w) {
                                    final uObj = appState.users.firstWhere((u) => u.id == w.ownerId, orElse: () => AppUser(id: w.ownerId, username: w.ownerId, password: '', role: w.ownerType, name: w.ownerId, twoFAEnabled: false));
                                    final label = '${uObj.name} (${w.ownerType}) — ${w.balance.toInt()} AED';
                                    return DropdownMenuItem(value: w, child: Text(label, style: const TextStyle(fontSize: 11.5)));
                                  }).toList(),
                                  onChanged: (val) => setState(() => _adjustTargetWallet = val),
                                  validator: (val) => val == null ? 'Target wallet required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _adjustAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Adjustment Amount (AED) *',
                                    hintText: 'e.g. 100 or -50',
                                    helperText: 'Use positive numbers to add, negative to deduct.',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Amount required';
                                    if (double.tryParse(val) == null) return 'Enter a valid decimal';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _adjustRemarksController,
                                  decoration: const InputDecoration(labelText: 'Adjustment Remarks *', hintText: 'Reason...'),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Remarks required' : null,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _isAdjusting ? null : () => _handleAdjustBalance(appState),
                                  icon: _isAdjusting
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                      : const Icon(Icons.compare_arrows, size: 16),
                                  label: const Text('Adjust Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Search field
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search wallets...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    const Text('Active Wallets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (walletsList.isEmpty)
                      const Center(
                        child: Text('No wallets found.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: walletsList.length,
                        itemBuilder: (context, index) {
                          final w = walletsList[index];
                          final uObj = appState.users.firstWhere((u) => u.id == w.ownerId, orElse: () => AppUser(id: w.ownerId, username: w.ownerId, password: '', role: w.ownerType, name: w.ownerId, twoFAEnabled: false));
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  w.ownerType ?? 'Wallet',
                                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${w.balance.toInt()}',
                                      style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 2),
                                    const Text('AED', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(uObj.name, style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    Text('ID: ${w.id}', style: const TextStyle(fontSize: 8.5, color: Colors.grey, fontFamily: 'monospace')),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Tab 2: Cash In Hand Report
            RefreshIndicator(
              onRefresh: () => appState.refreshDbState(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.15)),
                            ),
                            child: Column(
                              children: [
                                const Text('Total Cash In Hand', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${totalCashInHand.toInt()} AED', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.15)),
                            ),
                            child: Column(
                              children: [
                                const Text('Staff pending', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${cashInHandEntries.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (cashInHandEntries.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Highest Representative balance:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text('$highestName (${highestBalance.toInt()} AED)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Text('Staff Cash Balances', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (cashInHandEntries.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Text('All staff wallets are empty or reconciled.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cashInHandEntries.length,
                        itemBuilder: (context, index) {
                          final entry = cashInHandEntries[index];
                          final AppUser u = entry['user'] as AppUser;
                          final double bal = entry['totalBalance'] as double;
                          final List<Wallet> entryWallets = entry['wallets'] as List<Wallet>;

                          final String siteLabel = entryWallets.map((w) {
                            final site = appState.sites.firstWhere((s) => s.id == w.siteId, orElse: () => Site(id: '', name: 'Global', location: '', status: '', smsEnabled: false));
                            return '${site.name} (${w.balance.toInt()} AED)';
                          }).join(', ');

                          final rankColor = index < 3 ? rankColors[index] : Colors.grey[300]!;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: rankColor,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('Role: ${u.role}  •  Scope: $siteLabel', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ),
                              trailing: Text(
                                '${bal.toInt()} AED',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: bal > 500 ? Colors.red : bal > 200 ? Colors.amber[800] : Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
