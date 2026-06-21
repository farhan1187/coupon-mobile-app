class SystemSettings {
  final int lowStockThreshold;
  final String telegramWebhookUrl;
  final bool whatsappNotificationEnabled;
  final bool twoFactorEnabled;
  final String smsProvider; // 'twilio' or 'msegat'
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioFromNumber;
  final String msegatUserName;
  final String msegatApiKey;
  final String msegatSenderName;

  SystemSettings({
    required this.lowStockThreshold,
    required this.telegramWebhookUrl,
    required this.whatsappNotificationEnabled,
    required this.twoFactorEnabled,
    required this.smsProvider,
    required this.twilioAccountSid,
    required this.twilioAuthToken,
    required this.twilioFromNumber,
    required this.msegatUserName,
    required this.msegatApiKey,
    required this.msegatSenderName,
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 5,
      telegramWebhookUrl: json['telegram_webhook_url'] as String? ?? '',
      whatsappNotificationEnabled: json['whatsapp_notification_enabled'] == true,
      twoFactorEnabled: json['two_factor_enabled'] == true,
      smsProvider: json['sms_provider'] as String? ?? 'twilio',
      twilioAccountSid: json['twilio_account_sid'] as String? ?? '',
      twilioAuthToken: json['twilio_auth_token'] as String? ?? '',
      twilioFromNumber: json['twilio_from_number'] as String? ?? '',
      msegatUserName: json['msegat_user_name'] as String? ?? '',
      msegatApiKey: json['msegat_api_key'] as String? ?? '',
      msegatSenderName: json['msegat_sender_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'low_stock_threshold': lowStockThreshold,
      'telegram_webhook_url': telegramWebhookUrl,
      'whatsapp_notification_enabled': whatsappNotificationEnabled,
      'two_factor_enabled': twoFactorEnabled,
      'sms_provider': smsProvider,
      'twilio_account_sid': twilioAccountSid,
      'twilio_auth_token': twilioAuthToken,
      'twilio_from_number': twilioFromNumber,
      'msegat_user_name': msegatUserName,
      'msegat_api_key': msegatApiKey,
      'msegat_sender_name': msegatSenderName,
    };
  }
}
