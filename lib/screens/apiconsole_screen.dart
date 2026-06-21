import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/coupon.dart';
import '../models/coupon_profile.dart';

class ApiConsoleScreen extends StatefulWidget {
  const ApiConsoleScreen({super.key});

  @override
  State<ApiConsoleScreen> createState() => _ApiConsoleScreenState();
}

class _ApiConsoleScreenState extends State<ApiConsoleScreen> {
  String _activeEndpoint = 'validate';
  final _jsonController = TextEditingController();
  Map<String, dynamic>? _apiResponse;
  bool _loading = false;

  final Map<String, Map<String, dynamic>> _endpointSpecs = {
    'validate': {
      'method': 'GET',
      'path': '/api/coupons/validate',
      'desc': 'Verify if a coupon code exists, check its status, and inspect package profile details.',
      'defaultPayload': {'code': 'XYZ-12345'},
    },
    'import': {
      'method': 'POST',
      'path': '/api/coupons/import',
      'desc': 'Bulk import coupon records directly into the Admin stock pool using JSON format arrays.',
      'defaultPayload': {
        'coupons': [
          {'code': 'REST-API-001', 'serialNumber': 'SN-REST-001', 'profileName': '30 Days Premium'},
          {'code': 'REST-API-002', 'serialNumber': 'SN-REST-002', 'profileName': '15 Days Unlimited'},
        ]
      },
    },
    'sale': {
      'method': 'POST',
      'path': '/api/sales/create',
      'desc': 'Trigger a retail coupon sale activation from an external partner system or merchant dashboard.',
      'defaultPayload': {
        'couponCode': 'XYZ-123',
        'customerName': 'External API Client',
        'customerPhone': '+971501112222',
        'remarks': 'Activated via developer REST API console client',
      },
    }
  };

  @override
  void initState() {
    super.initState();
    _loadDefaultPayload();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _loadDefaultPayload() {
    final spec = _endpointSpecs[_activeEndpoint]!;
    final defaultData = Map<String, dynamic>.from(spec['defaultPayload'] as Map);

    // Try to pre-fill with real data if possible
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (_activeEndpoint == 'validate') {
      if (appState.coupons.isNotEmpty) {
        defaultData['code'] = appState.coupons.first.code;
      }
    } else if (_activeEndpoint == 'sale') {
      final availableCoupon = appState.coupons.firstWhere(
        (c) => c.status == 'Available',
        orElse: () => Coupon(id: '', code: '', profileId: '', status: '', cost: 0.0, salePrice: 0.0, createdAt: '', history: const []),
      );
      if (availableCoupon.code.isNotEmpty) {
        defaultData['couponCode'] = availableCoupon.code;
      }
    }

    _jsonController.text = const JsonEncoder.withIndent('  ').convert(defaultData);
    _apiResponse = null;
  }

  void _handleEndpointSwitch(String key) {
    setState(() {
      _activeEndpoint = key;
      _loadDefaultPayload();
    });
  }

  void _executeRequest(AppStateProvider appState) async {
    setState(() {
      _loading = true;
      _apiResponse = null;
    });

    // Simulate 1s latency matching the web console
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final payload = json.decode(_jsonController.text.trim());

      if (_activeEndpoint == 'validate') {
        final code = payload['code'];
        if (code == null || code.toString().trim().isEmpty) {
          throw Exception('Query parameter "code" is required');
        }

        final coupon = appState.coupons.firstWhere(
          (c) => c.code == code,
          orElse: () => Coupon(id: '', code: '', profileId: '', status: '', cost: 0.0, salePrice: 0.0, createdAt: '', history: const []),
        );

        if (coupon.id.isEmpty) {
          setState(() {
            _apiResponse = {
              'status': 404,
              'statusText': 'Not Found',
              'body': {'error': 'Coupon code "$code" not registered'},
            };
          });
        } else {
          final profile = appState.couponProfiles.firstWhere(
            (p) => p.id == coupon.profileId,
            orElse: () => CouponProfile(id: '', name: 'Unknown', validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
          );

          setState(() {
            _apiResponse = {
              'status': 200,
              'statusText': 'OK',
              'body': {
                'couponCode': coupon.code,
                'serialNumber': coupon.id,
                'status': coupon.status,
                'siteId': coupon.siteId,
                'profile': {
                  'name': profile.name,
                  'validityDays': profile.validityDays,
                  'salePrice': profile.salePrice,
                }
              },
            };
          });
        }
      } else if (_activeEndpoint == 'import') {
        final couponsList = payload['coupons'];
        if (couponsList == null || couponsList is! List) {
          throw Exception('Payload property "coupons" must be an array');
        }

        final List<String> csvLines = [];
        for (var c in couponsList) {
          if (c is! Map) continue;
          final cCode = c['code'] ?? '';
          final cSerial = c['serialNumber'] ?? '';
          final cProfile = c['profileName'] ?? '';
          if (cCode.toString().isEmpty || cProfile.toString().isEmpty) {
            throw Exception('Each coupon must specify at least code and profileName');
          }
          csvLines.add('$cCode, $cProfile, 0, 0, $cSerial');
        }

        final res = await appState.importCoupons(csvLines, siteId: null);

        setState(() {
          _apiResponse = {
            'status': 201,
            'statusText': 'Created',
            'body': {
              'success': true,
              'importedCount': res['count'],
              'details': 'Coupons imported successfully into Admin pool',
              'errors': res['errors'],
            },
          };
        });
      } else if (_activeEndpoint == 'sale') {
        final couponCode = payload['couponCode'];
        if (couponCode == null || couponCode.toString().isEmpty) {
          throw Exception('Property "couponCode" is required');
        }

        final coupon = appState.coupons.firstWhere(
          (c) => c.code == couponCode,
          orElse: () => Coupon(id: '', code: '', profileId: '', status: '', cost: 0.0, salePrice: 0.0, createdAt: '', history: const []),
        );

        if (coupon.id.isEmpty) {
          throw Exception('Coupon code "$couponCode" not found');
        }

        final res = await appState.sellCoupon(
          profileId: coupon.profileId,
          customerName: payload['customerName'] ?? 'External API Client',
          customerPhone: payload['customerPhone'] ?? '',
          remarks: payload['remarks'] ?? 'Sold via REST API Console',
        );

        setState(() {
          _apiResponse = {
            'status': 200,
            'statusText': 'OK',
            'body': {
              'success': true,
              'transactionId': res['transactionId'],
              'couponCode': res['couponCode'],
              'status': 'Sold',
              'creditedTo': appState.currentUser?.name ?? 'System',
            },
          };
        });
      }
    } catch (e) {
      setState(() {
        _apiResponse = {
          'status': 400,
          'statusText': 'Bad Request',
          'body': {'error': e.toString().replaceFirst('Exception: ', '')},
        };
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Title Description
            const Text(
              'Developer REST API Docs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Inspect endpoints specs and test API requests against the active database state.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Endpoint list
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _endpointSpecs.keys.map((key) {
                  final spec = _endpointSpecs[key]!;
                  final isActive = _activeEndpoint == key;
                  final isGet = spec['method'] == 'GET';

                  return InkWell(
                    onTap: () => _handleEndpointSwitch(key),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? (isDark ? const Color(0xFF1E293B) : Colors.indigo.withOpacity(0.05))
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isGet
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  spec['method'] as String,
                                  style: TextStyle(
                                    color: isGet ? Colors.green : Colors.blue,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  spec['path'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            spec['desc'] as String,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Sandbox payload Editor
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Request Sandbox Payload', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _jsonController,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _loading ? null : () => _executeRequest(appState),
                      icon: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Icon(Icons.play_arrow, size: 16),
                      label: Text(_loading ? 'Executing request...' : 'Execute Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Simulated terminal response window
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'API Response Terminal',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      if (_apiResponse != null) ...[
                        Row(
                          children: [
                            Icon(
                              (_apiResponse!['status'] as int) < 300
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 14,
                              color: (_apiResponse!['status'] as int) < 300 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Status: ${_apiResponse!['status']} ${_apiResponse!['statusText']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (_apiResponse!['status'] as int) < 300 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 120),
                    child: _loading
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.indigoAccent)),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Executing API sync transaction...',
                                  style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                                )
                              ],
                            ),
                          )
                        : _apiResponse != null
                            ? SelectableText(
                                const JsonEncoder.withIndent('  ').convert(_apiResponse!['body']),
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.terminal, size: 28, color: Colors.white24),
                                    SizedBox(height: 8),
                                    Text(
                                      'Waiting for request execution...',
                                      style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                                    )
                                  ],
                                ),
                              ),
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
