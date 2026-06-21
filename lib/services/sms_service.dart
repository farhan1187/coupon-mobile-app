import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/settings.dart';

class SmsService {
  static const List<Map<String, dynamic>> gulfPrefixes = [
    {'prefix': '+971', 'name': 'UAE', 'localDigits': 9},
    {'prefix': '+966', 'name': 'KSA', 'localDigits': 9},
    {'prefix': '+974', 'name': 'Qatar', 'localDigits': 8},
    {'prefix': '+973', 'name': 'Bahrain', 'localDigits': 8},
    {'prefix': '+968', 'name': 'Oman', 'localDigits': 8},
  ];

  static const List<Map<String, dynamic>> twilioExtraPrefixes = [
    {'prefix': '+91', 'name': 'India', 'localDigits': 10},
  ];

  static List<Map<String, dynamic>> getPrefixes(String provider) {
    if (provider == 'twilio') {
      return [...gulfPrefixes, ...twilioExtraPrefixes];
    }
    return gulfPrefixes;
  }

  /// Normalises a raw phone number to E.164 format.
  String? normalisePhone(String raw) {
    String n = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (n.isEmpty) return null;

    // Already valid E.164
    if (RegExp(r'^\+\d{7,15}$').hasMatch(n)) return n;

    // 00-prefixed international
    if (RegExp(r'^00\d{7,14}$').hasMatch(n)) return '+' + n.substring(2);

    // Bare prefix without +
    if (RegExp(r'^971\d{8,9}$').hasMatch(n)) return '+' + n; // UAE
    if (RegExp(r'^966\d{8,9}$').hasMatch(n)) return '+' + n; // KSA
    if (RegExp(r'^974\d{7,8}$').hasMatch(n)) return '+' + n; // Qatar
    if (RegExp(r'^973\d{7,8}$').hasMatch(n)) return '+' + n; // Bahrain
    if (RegExp(r'^968\d{7,8}$').hasMatch(n)) return '+' + n; // Oman
    if (RegExp(r'^91\d{10}$').hasMatch(n)) return '+' + n; // India

    // Gulf local: 05xxxxxxxx or 5xxxxxxxx (UAE default for ambiguous)
    if (RegExp(r'^05\d{8}$').hasMatch(n)) return '+971' + n.substring(1);
    if (RegExp(r'^5\d{8}$').hasMatch(n)) return '+971' + n;

    // Qatar/Bahrain/Oman local 8-digit starting with 3, 6, 7, 9
    if (RegExp(r'^[3679]\d{7}$').hasMatch(n)) return '+974' + n; // assume Qatar

    // India local: 10-digit starting with 6–9
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(n)) return '+91' + n;

    return null;
  }

  /// Check if a number is allowed for the given provider.
  bool isAllowedForProvider(String e164, String provider) {
    final prefixes = getPrefixes(provider);
    return prefixes.any((p) => e164.startsWith(p['prefix'] as String));
  }

  /// Get supported countries text
  String getSupportedCountries(String provider) {
    if (provider == 'twilio') return 'UAE, KSA, Qatar, Bahrain, Oman, India';
    return 'UAE, KSA, Qatar, Bahrain, Oman';
  }

  // ── Twilio REST Client ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _sendViaTwilio(
    String accountSid,
    String authToken,
    String fromNumber,
    String to,
    String body,
  ) async {
    if (accountSid.isEmpty || authToken.isEmpty || fromNumber.isEmpty) {
      throw Exception('Twilio credentials incomplete (Account SID, Auth Token, From Number required).');
    }

    final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));
    final Uri url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': basicAuth,
      },
      body: {
        'To': to,
        'From': fromNumber,
        'Body': body,
      },
    );

    final responseData = json.decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(responseData['message'] ?? 'Twilio HTTP error ${response.statusCode}');
    }
    return {'sid': responseData['sid']};
  }

  // ── Msegat REST Client ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _sendViaMsegat(
    String userName,
    String apiKey,
    String userSender,
    String to,
    String body,
  ) async {
    if (userName.isEmpty || apiKey.isEmpty || userSender.isEmpty) {
      throw Exception('Msegat credentials incomplete (Username, API Key, Sender ID required).');
    }

    final Uri url = Uri.parse('https://www.msegat.com/gw/sendsms.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userName': userName,
        'apiKey': apiKey,
        'userSender': userSender,
        'numbers': to.replaceAll('+', ''),
        'msg': body,
        'msgEncoding': 'UTF8',
      }),
    );

    final String text = response.body.trim();
    final Map<String, String> errors = {
      'M0001': 'Invalid username/password',
      'M0002': 'Sender ID not active',
      'M0003': 'Invalid mobile number',
      'M0004': 'Insufficient balance',
    };

    if (text != '1') {
      throw Exception(errors[text] ?? 'Msegat error: $text');
    }
    return {'code': text};
  }

  // ── Main Interface ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendCouponSms({
    required SystemSettings settings,
    required String phone,
    required String couponCode,
    required String profileName,
  }) async {
    try {
      final String? e164 = normalisePhone(phone);
      if (e164 == null) {
        return {
          'success': false,
          'error': 'Could not recognise the phone number. Enter with country code, e.g. +971xxxxxxxx or +91xxxxxxxxxx.'
        };
      }

      final String provider = settings.smsProvider;

      if (!isAllowedForProvider(e164, provider)) {
        final supported = getSupportedCountries(provider);
        return {
          'success': false,
          'error': '${provider == "msegat" ? "Msegat" : "Twilio"} supports: $supported only.'
        };
      }

      final String message = 'Your ${profileName.isNotEmpty ? profileName : "internet access"} coupon code is: $couponCode\n'
          'This code activates your session. Do not share it with others.';

      if (provider == 'twilio') {
        await _sendViaTwilio(
          settings.twilioAccountSid,
          settings.twilioAuthToken,
          settings.twilioFromNumber,
          e164,
          message,
        );
      } else {
        await _sendViaMsegat(
          settings.msegatUserName,
          settings.msegatApiKey,
          settings.msegatSenderName,
          e164,
          message,
        );
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }
}
