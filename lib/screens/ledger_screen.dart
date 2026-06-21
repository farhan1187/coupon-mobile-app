import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/transaction.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _reversalReasonController = TextEditingController();
  bool _isReversing = false;

  @override
  void dispose() {
    _reversalReasonController.dispose();
    super.dispose();
  }

  void _triggerReversal(BuildContext context, AppStateProvider appState, AppTransaction tx) {
    _reversalReasonController.clear();
    showDialog(
      context: context,
      barrierDismissible: !_isReversing,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Confirm Transaction Reversal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Are you sure you want to reverse transaction ${tx.id}? This will reverse the wallet balances accordingly.',
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reversalReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reversal Reason',
                      hintText: 'e.g. Incorrect allocation',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isReversing,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isReversing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isReversing
                      ? null
                      : () async {
                          final reason = _reversalReasonController.text.trim();
                          if (reason.isEmpty) {
                            appState.showToast('Reason is required');
                            return;
                          }
                          setModalState(() => _isReversing = true);
                          try {
                            await appState.reverseTransaction(tx.id, reason);
                            if (mounted) Navigator.of(context).pop();
                          } catch (_) {
                            // error toast shown by provider
                          } finally {
                            if (mounted) setModalState(() => _isReversing = false);
                          }
                        },
                  child: _isReversing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Reverse'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    final isAccountantOrAdmin = ['Admin', 'Accountant', 'Owner'].contains(user.role);

    // Role-scoped transaction filter
    List<AppTransaction> filteredTxs = appState.transactions;
    if (!['Admin', 'Accountant'].contains(user.role)) {
      final walletIds = appState.wallets
          .where((w) => w.ownerId == user.id)
          .map((w) => w.id)
          .toSet();
      filteredTxs = filteredTxs
          .where((tx) =>
              walletIds.contains(tx.fromWalletId) ||
              walletIds.contains(tx.toWalletId) ||
              tx.createdByUserId == user.id)
          .toList();
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => appState.refreshDbState(),
        child: filteredTxs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.history_edu, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No transactions logged yet',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Financial records will appear here.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredTxs.length,
                itemBuilder: (context, index) {
                  final tx = filteredTxs[index];
                  final isReversal   = tx.type == 'REVERSAL';
                  final isAdjustment = tx.type == 'ADJUSTMENT';
                  final isSale       = tx.type == 'SALE';

                  final dateStr = tx.timestamp.length >= 10 ? tx.timestamp.substring(0, 10) : '';
                  final timeStr = tx.timestamp.length >= 19 ? tx.timestamp.substring(11, 16) : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isReversal
                                      ? Colors.red.withOpacity(0.08)
                                      : isAdjustment
                                          ? Colors.amber.withOpacity(0.08)
                                          : isSale
                                              ? Colors.green.withOpacity(0.08)
                                              : Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tx.type,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isReversal
                                        ? Colors.red
                                        : isAdjustment
                                            ? Colors.amber[800]
                                            : isSale
                                                ? Colors.green
                                                : Colors.blue,
                                  ),
                                ),
                              ),
                              Text(
                                '${tx.amount.toInt()} AED',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isReversal ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(tx.remarks,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'From: ${tx.fromWalletId ?? "SYSTEM"}  ->  To: ${tx.toWalletId ?? "SYSTEM"}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'By: ${tx.createdByUserId} • $dateStr $timeStr',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              if (isAccountantOrAdmin && !isReversal)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(40, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.settings_backup_restore, size: 12),
                                  label: const Text('Reverse',
                                      style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _triggerReversal(context, appState, tx),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
