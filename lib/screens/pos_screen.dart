import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon_profile.dart';
import '../models/site.dart';
import '../services/sms_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final SmsService _smsService = SmsService();
  String _profileFilter = 'all';

  // Checkout Form Controllers
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _isSelling = false;

  // SMS Gateway controllers
  final _smsPhoneController = TextEditingController();
  bool _smsSending = false;
  bool _smsSent = false;
  String _smsError = '';

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _remarksController.dispose();
    _smsPhoneController.dispose();
    super.dispose();
  }

  double _getProfilePrice(AppStateProvider appState, String profileId) {
    final siteId = appState.selectedSiteId;
    final sp = appState.sitePrices.firstWhere(
      (element) => element['siteId'] == siteId && element['profileId'] == profileId,
      orElse: () => <String, dynamic>{},
    );
    if (sp.isNotEmpty) {
      return sp['salePrice'] as double;
    }
    final prof = appState.couponProfiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => CouponProfile(id: '', name: '', validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
    );
    return prof.salePrice;
  }

  int _getProfileStock(AppStateProvider appState, String profileId) {
    final siteId = appState.selectedSiteId;
    return appState.coupons.where((c) =>
        c.siteId == siteId &&
        c.profileId == profileId &&
        c.status == 'Available').length;
  }

  void _triggerCheckout(BuildContext context, AppStateProvider appState, CouponProfile profile) {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _remarksController.clear();

    final price = _getProfilePrice(appState, profile.id);

    showDialog(
      context: context,
      barrierDismissible: !_isSelling,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Confirm Coupon Activation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Package:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(profile.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Validity:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${profile.validityDays} Days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Price Charged:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${price.toInt()} AED', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name (Optional)',
                        hintText: 'e.g. John Doe',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isSelling,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Customer Phone (Optional)',
                        hintText: 'e.g. +971501234567',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isSelling,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks',
                        hintText: 'Payment notes...',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isSelling,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSelling ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSelling
                      ? null
                      : () async {
                          setModalState(() => _isSelling = true);
                          try {
                            final res = await appState.sellCoupon(
                              profileId: profile.id,
                              customerName: _customerNameController.text.trim(),
                              customerPhone: _customerPhoneController.text.trim(),
                              remarks: _remarksController.text.trim(),
                            );
                            if (mounted) {
                              Navigator.of(context).pop(); // close confirm dialog
                              _showSuccessReceipt(context, appState, res['couponCode'] as String, profile.name);
                            }
                          } catch (e) {
                            // error is handled by provider toast
                          } finally {
                            if (mounted) {
                              setModalState(() => _isSelling = false);
                            }
                          }
                        },
                  child: _isSelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Complete Sale'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessReceipt(BuildContext context, AppStateProvider appState, String code, String profileName) {
    _smsPhoneController.text = _customerPhoneController.text.trim();
    _smsSent = false;
    _smsSending = false;
    _smsError = '';

    final Site currentSite = appState.sites.firstWhere(
      (s) => s.id == appState.selectedSiteId,
      orElse: () => Site(id: '', name: '', location: '', status: '', smsEnabled: true),
    );
    final bool smsEnabledForSite = currentSite.smsEnabled;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSmsState) {
            final double e164 = double.tryParse(_smsService.normalisePhone(_smsPhoneController.text.trim()) ?? '') ?? 0;
            final bool phoneValid = e164 > 0 && _smsService.isAllowedForProvider(
              _smsService.normalisePhone(_smsPhoneController.text.trim())!,
              appState.settings.smsProvider,
            );

            final bool smsConfigured = appState.settings.smsProvider == 'twilio'
                ? (appState.settings.twilioAccountSid.isNotEmpty && appState.settings.twilioAuthToken.isNotEmpty)
                : (appState.settings.msegatUserName.isNotEmpty && appState.settings.msegatApiKey.isNotEmpty);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Center(
                child: Text(
                  '✓ Sale Completed',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Give this coupon code to the customer to activate their session:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2, style: BorderStyle.solid),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (smsEnabledForSite) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _smsSent ? Icons.done_all : Icons.message_outlined,
                            size: 16,
                            color: _smsSent ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _smsSent ? 'SMS Sent!' : 'Send Access Code via SMS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _smsSent ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_smsSent) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _smsPhoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: '+971501234567',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setSmsState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: (!phoneValid || _smsSending || !smsConfigured)
                                  ? null
                                  : () async {
                                      setSmsState(() {
                                        _smsSending = true;
                                        _smsError = '';
                                      });
                                      
                                      final res = await _smsService.sendCouponSms(
                                        settings: appState.settings,
                                        phone: _smsPhoneController.text.trim(),
                                        couponCode: code,
                                        profileName: profileName,
                                      );

                                      if (mounted) {
                                        setSmsState(() {
                                          _smsSending = false;
                                          if (res['success'] == true) {
                                            _smsSent = true;
                                          } else {
                                            _smsError = res['error'] as String? ?? 'SMS sending failed.';
                                          }
                                        });
                                      }
                                    },
                              child: _smsSending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                    )
                                  : const Text('Send'),
                            )
                          ],
                        ),
                        if (_smsPhoneController.text.isNotEmpty && !phoneValid)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Supports: ${_smsService.getSupportedCountries(appState.settings.smsProvider)}',
                              style: const TextStyle(color: Colors.amber, fontSize: 10),
                            ),
                          ),
                        if (phoneValid && !smsConfigured)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'SMS Provider keys are not configured. Ask Admin to set them up.',
                              style: TextStyle(color: Colors.amber, fontSize: 10),
                            ),
                          ),
                        if (_smsError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _smsError,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                            ),
                          ),
                      ],
                      if (_smsSent)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'SMS dispatched successfully.',
                            style: TextStyle(color: Colors.green, fontSize: 11),
                          ),
                        ),
                    ]
                  ],
                ),
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close & Continue'),
                  ),
                )
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

    // Site Guard
    if (appState.selectedSiteId == 'all' || appState.selectedSiteId == 'none') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Select a Specific Site',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a specific retail location from the site dropdown in the top bar to initialize checkout.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Subscription Expiry Guard
    final currentSite = appState.sites.where((s) => s.id == appState.selectedSiteId).isNotEmpty
        ? appState.sites.firstWhere((s) => s.id == appState.selectedSiteId)
        : null;

    if (currentSite != null && !currentSite.isSubscriptionActive) {
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
                    'The subscription for ${currentSite.name} has expired. Coupon sales have been temporarily suspended. Service will resume automatically once the subscription is renewed by an Admin.',
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

    // Load profiles assigned to this site
    final assignedProfileIds = appState.sitePrices
        .where((sp) => sp['siteId'] == appState.selectedSiteId)
        .map((sp) => sp['profileId'] as String)
        .toSet();

    List<CouponProfile> list = appState.couponProfiles
        .where((p) => assignedProfileIds.contains(p.id))
        .toList();

    if (_profileFilter != 'all') {
      list = list.where((p) => p.id == _profileFilter).toList();
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Selector
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Filter Package',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    value: _profileFilter,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Packages')),
                      ...appState.couponProfiles
                          .where((p) => assignedProfileIds.contains(p.id))
                          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _profileFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Products Grid
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No assigned packages', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('An administrator needs to assign packages to this site first.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final profile = list[index];
                        final double price = _getProfilePrice(appState, profile.id);
                        final int stock = _getProfileStock(appState, profile.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.15)),
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
                                    Text(
                                      profile.name,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${profile.validityDays} Days',
                                        style: const TextStyle(
                                          color: Color(0xFF6366F1),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  profile.description,
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Available stock:',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: stock > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$stock units',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: stock > 0 ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Retail Price', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          '${price.toInt()} AED',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: stock == 0 ? null : () => _triggerCheckout(context, appState, profile),
                                      child: Text(stock > 0 ? 'Activate Sale' : 'Out of Stock'),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}
