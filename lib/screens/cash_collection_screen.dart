import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/cash_collection.dart';
import '../models/site.dart';

class CashCollectionScreen extends StatefulWidget {
  const CashCollectionScreen({super.key});

  @override
  State<CashCollectionScreen> createState() => _CashCollectionScreenState();
}

class _CashCollectionScreenState extends State<CashCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  AppUser? _selectedUser;
  bool _isCollecting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ── Role Collection Rules ──────────────────────────────────────────────────
  // Replicates the role collection permissions from mockDb.js
  List<AppUser> _getEligibleTargetUsers(AppStateProvider appState, String myRole) {
    final List<AppUser> allUsers = appState.users;

    switch (myRole) {
      case 'Super Staff':
        // Super Staff collects from Staff
        return allUsers.where((u) => u.role == 'Staff').toList();
      case 'Manager':
        // Manager collects from Staff (and Super Staff in standard workflow, wait, Manager role-hierarchy allows Staff and Super Staff in logs, but collect from Staff is primary. Let's allow Staff)
        return allUsers.where((u) => u.role == 'Staff' || u.role == 'Super Staff').toList();
      case 'Owner':
        // Owner collects from Manager, Super Staff, Staff
        return allUsers.where((u) => u.role == 'Manager' || u.role == 'Super Staff' || u.role == 'Staff').toList();
      case 'Accountant':
        // Accountant collects from Owner, Manager, Super Staff, Accountant (wait, Accountant collects from Owner, Manager, Super Staff)
        return allUsers.where((u) => u.role == 'Owner' || u.role == 'Manager' || u.role == 'Super Staff').toList();
      case 'Admin':
        // Admin can collect from everyone except system admin
        return allUsers.where((u) => u.id != 'u-sysadmin').toList();
      default:
        return [];
    }
  }

  double _getUserBalance(AppStateProvider appState, AppUser user) {
    if (user.role == 'Staff') {
      final w = appState.wallets.firstWhere(
        (wallet) => wallet.ownerId == user.id && wallet.ownerType == 'USER_SALES',
        orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0.0),
      );
      return w.balance;
    } else if (user.role == 'Super Staff') {
      // Super Staff has two wallets (sales + collection)
      final wSales = appState.wallets.firstWhere(
        (wallet) => wallet.ownerId == user.id && wallet.ownerType == 'USER_SALES',
        orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0.0),
      );
      final wColl = appState.wallets.firstWhere(
        (wallet) => wallet.ownerId == user.id && wallet.ownerType == 'USER_COLLECTION',
        orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0.0),
      );
      return wSales.balance + wColl.balance;
    } else {
      // Manager/Owner/Accountant wallets are collection wallets
      final w = appState.wallets.firstWhere(
        (wallet) => wallet.ownerId == user.id && wallet.ownerType == 'USER_COLLECTION',
        orElse: () => Wallet(id: '', ownerId: '', ownerType: '', balance: 0.0),
      );
      return w.balance;
    }
  }

  void _handleCollectCash(AppStateProvider appState) async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) return;

    setState(() => _isCollecting = true);
    final double amount = double.parse(_amountController.text.trim());
    final String remarks = _remarksController.text.trim();
    final String targetRole = _selectedUser!.role;

    try {
      if (targetRole == 'Staff') {
        await appState.collectCashFromStaff(
          collectedFromUserId: _selectedUser!.id,
          amount: amount,
          siteId: appState.selectedSiteId == 'all' || appState.selectedSiteId == 'none' ? null : appState.selectedSiteId,
          remarks: remarks,
        );
      } else if (targetRole == 'Super Staff') {
        // Super Staff collection has split wallet deductions
        final Map<String, dynamic> split = {
          'amount': amount,
          'siteId': appState.selectedSiteId == 'all' || appState.selectedSiteId == 'none' ? null : appState.selectedSiteId,
        };
        await appState.collectCashFromSuperStaff(
          collectedFromUserId: _selectedUser!.id,
          splits: [split],
          remarks: remarks,
        );
      } else if (targetRole == 'Manager') {
        await appState.collectCashFromManager(
          collectedFromUserId: _selectedUser!.id,
          amount: amount,
          siteId: appState.selectedSiteId == 'all' || appState.selectedSiteId == 'none' ? null : appState.selectedSiteId,
          remarks: remarks,
        );
      } else if (targetRole == 'Owner') {
        await appState.collectCashFromOwner(
          collectedFromUserId: _selectedUser!.id,
          amount: amount,
          siteId: appState.selectedSiteId == 'all' || appState.selectedSiteId == 'none' ? null : appState.selectedSiteId,
          remarks: remarks,
        );
      } else {
        // Admin fallback wallet adjustment or similar
        throw Exception('Direct collections not supported for role $targetRole. Use Adjustments.');
      }

      _amountController.clear();
      _remarksController.clear();
      setState(() => _selectedUser = null);
    } catch (e) {
      // Toast message shows the error
    } finally {
      setState(() => _isCollecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final currentUser = appState.currentUser;
    if (currentUser == null) return const SizedBox();

    final myRole = currentUser.role;
    final isStaff = myRole == 'Staff';

    final eligibleUsers = _getEligibleTargetUsers(appState, myRole);

    // Filter collection logs visible to this user
    List<CashCollection> listLogs = appState.cashCollections;
    if (!['Admin', 'Accountant'].contains(myRole)) {
      listLogs = listLogs.where((log) =>
          log.collectedByUserId == currentUser.id ||
          log.collectedFromUserId == currentUser.id).toList();
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // If Staff, show only balance & logs
            if (isStaff) ...[
              Card(
                elevation: 0,
                color: Colors.green.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.withOpacity(0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text(
                        'Cash Sitting in Your Wallet',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getUserBalance(appState, currentUser).toInt()} AED',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This balance represents your retail coupon sales. A Super Staff member, Manager, or Owner will physically collect this cash and clear your balance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Collection form
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Collect Cash From Representative',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        // Select target user
                        DropdownButtonFormField<AppUser>(
                          decoration: const InputDecoration(
                            labelText: 'Select Staff / Manager',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedUser,
                          items: eligibleUsers.map((u) {
                            final double bal = _getUserBalance(appState, u);
                            return DropdownMenuItem<AppUser>(
                              value: u,
                              child: Text('${u.name} (${u.role}) — ${bal.toInt()} AED'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedUser = val;
                              _amountController.clear();
                            });
                          },
                          validator: (value) => value == null ? 'Target user is required' : null,
                        ),
                        
                        if (_selectedUser != null) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount (AED)',
                              hintText: 'Enter cash collected amount',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Amount is required';
                              }
                              final double? amt = double.tryParse(value);
                              if (amt == null || amt <= 0) {
                                return 'Enter a valid positive number';
                              }
                              final double limit = _getUserBalance(appState, _selectedUser!);
                              if (amt > limit) {
                                return 'Exceeds representative wallet limit of ${limit.toInt()} AED';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _remarksController,
                            decoration: const InputDecoration(
                              labelText: 'Collection Remarks',
                              hintText: 'e.g. Cleared sales cash',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isCollecting ? null : () => _handleCollectCash(appState),
                            child: _isCollecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  )
                                : const Text('Confirm Cash Collection', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Cash Collections History list
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
                      'Collection History & Logs',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (listLogs.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Text(
                            'No collection records found',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: listLogs.length,
                        itemBuilder: (context, index) {
                          final log = listLogs[index];
                          final fromUser = appState.users.firstWhere((u) => u.id == log.collectedFromUserId, orElse: () => AppUser(id: log.collectedFromUserId, username: log.collectedFromUserId, password: '', role: 'Staff', name: log.collectedFromUserId, twoFAEnabled: false));
                          final byUser = appState.users.firstWhere((u) => u.id == log.collectedByUserId, orElse: () => AppUser(id: log.collectedByUserId, username: log.collectedByUserId, password: '', role: 'Super Staff', name: log.collectedByUserId, twoFAEnabled: false));
                          
                          final dateStr = log.timestamp.length >= 10 ? log.timestamp.substring(0, 10) : '';
                          final timeStr = log.timestamp.length >= 19 ? log.timestamp.substring(11, 16) : '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              child: const Icon(Icons.currency_exchange, color: Colors.purple, size: 18),
                            ),
                            title: Text(
                              '${log.amount.toInt()} AED Collected',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  'From: ${fromUser.name} (${fromUser.role})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  'By: ${byUser.name} • $dateStr $timeStr',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                                if (log.remarks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Notes: ${log.remarks}',
                                      style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
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
