import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Field Controllers
  final _thresholdController = TextEditingController();
  final _telegramController = TextEditingController();
  bool _whatsappEnabled = false;
  bool _twoFactorEnabled = false;
  String _smsProvider = 'twilio';

  // Twilio Fields
  final _twilioSidController = TextEditingController();
  final _twilioTokenController = TextEditingController();
  final _twilioFromController = TextEditingController();

  // Msegat Fields
  final _msegatUserController = TextEditingController();
  final _msegatApiKeyController = TextEditingController();
  final _msegatSenderController = TextEditingController();

  bool _isSaving = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    // Load initial values from AppState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final s = appState.settings;
      _thresholdController.text = s.lowStockThreshold.toString();
      _telegramController.text = s.telegramWebhookUrl;
      setState(() {
        _whatsappEnabled = s.whatsappNotificationEnabled;
        _twoFactorEnabled = s.twoFactorEnabled;
        _smsProvider = s.smsProvider;
      });
      _twilioSidController.text = s.twilioAccountSid;
      _twilioTokenController.text = s.twilioAuthToken;
      _twilioFromController.text = s.twilioFromNumber;

      _msegatUserController.text = s.msegatUserName;
      _msegatApiKeyController.text = s.msegatApiKey;
      _msegatSenderController.text = s.msegatSenderName;
    });
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _telegramController.dispose();
    _twilioSidController.dispose();
    _twilioTokenController.dispose();
    _twilioFromController.dispose();
    _msegatUserController.dispose();
    _msegatApiKeyController.dispose();
    _msegatSenderController.dispose();
    super.dispose();
  }

  void _saveSettings(AppStateProvider appState) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final newSettings = SystemSettings(
      lowStockThreshold: int.parse(_thresholdController.text.trim()),
      telegramWebhookUrl: _telegramController.text.trim(),
      whatsappNotificationEnabled: _whatsappEnabled,
      twoFactorEnabled: _twoFactorEnabled,
      smsProvider: _smsProvider,
      twilioAccountSid: _twilioSidController.text.trim(),
      twilioAuthToken: _twilioTokenController.text.trim(),
      twilioFromNumber: _twilioFromController.text.trim(),
      msegatUserName: _msegatUserController.text.trim(),
      msegatApiKey: _msegatApiKeyController.text.trim(),
      msegatSenderName: _msegatSenderController.text.trim(),
    );

    await appState.updateSettings(newSettings);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _confirmDatabaseReset(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      barrierDismissible: !_isResetting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('🚨 Warning: Database Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              content: const Text(
                'This will permanently delete all transaction history, sales logs, cash collections, and coupons except for the system administrator user. This action CANNOT be undone.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: _isResetting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isResetting
                      ? null
                      : () async {
                          setModalState(() => _isResetting = true);
                          try {
                            await appState.resetDatabase();
                            if (mounted) {
                              Navigator.of(context).pop(); // close modal
                            }
                          } catch (e) {
                            // toast error handles it
                          } finally {
                            if (mounted) {
                              setModalState(() => _isResetting = false);
                            }
                          }
                        },
                  child: _isResetting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Reset Database'),
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
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    final isAdmin = user.role == 'Admin';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. General Config Card
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
                      const Text('General Configurations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low Stock Alert Threshold',
                          hintText: 'e.g. 5',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Threshold required';
                          if (int.tryParse(value) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telegramController,
                        decoration: const InputDecoration(
                          labelText: 'Telegram Alert Webhook URL',
                          hintText: 'https://api.telegram.org/bot...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('WhatsApp Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Receive stock warnings via WhatsApp bot', style: TextStyle(fontSize: 11)),
                        value: _whatsappEnabled,
                        onChanged: (val) => setState(() => _whatsappEnabled = val),
                      ),
                      SwitchListTile(
                        title: const Text('Enforce Two-Factor Auth (2FA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Require OTP SMS upon staff logins', style: TextStyle(fontSize: 11)),
                        value: _twoFactorEnabled,
                        onChanged: (val) => setState(() => _twoFactorEnabled = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // 2. SMS Gateway Settings Card
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
                      const Text('SMS Gateway Integration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'SMS Provider',
                          border: OutlineInputBorder(),
                        ),
                        value: _smsProvider,
                        items: const [
                          DropdownMenuItem(value: 'twilio', child: Text('Twilio SMS Gateway')),
                          DropdownMenuItem(value: 'msegat', child: Text('Msegat SMS Gateway (Middle East)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _smsProvider = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Render provider specific credentials
                      if (_smsProvider == 'twilio') ...[
                        TextFormField(
                          controller: _twilioSidController,
                          decoration: const InputDecoration(
                            labelText: 'Twilio Account SID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _twilioTokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Twilio Auth Token',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _twilioFromController,
                          decoration: const InputDecoration(
                            labelText: 'Twilio From Phone Number',
                            hintText: 'e.g. +1415xxxxxxx',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _msegatUserController,
                          decoration: const InputDecoration(
                            labelText: 'Msegat Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _msegatApiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Msegat API Key',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _msegatSenderController,
                          decoration: const InputDecoration(
                            labelText: 'Msegat Sender Name ID',
                            hintText: 'e.g. VerifiedSender',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Save Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : () => _saveSettings(appState),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Save Configurations', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              // Reset Database procedures (Only for Admin role)
              if (isAdmin) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Danger Zone',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[800]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Performing a database reset will erase all collections, transactions, and user records. This is only recommended when initializing a fresh tenant.',
                          style: TextStyle(fontSize: 12, color: Colors.red[700], height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _confirmDatabaseReset(context, appState),
                          child: const Text('Reset Complete System', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
