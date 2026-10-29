import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the .NET API lives.
class ApiConfig {
  ApiConfig._();

  /// The live server address. When the company domain changes, change ONLY this line
  /// (or build with --dart-define=API_BASE=https://new-domain).
  static const productionApi = 'https://utopiahealth.cloudverve.in';

  static const _override = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // TestFlight / release builds talk to the real server.
    if (kReleaseMode) return productionApi;
    // Debug runs on this PC: the Android emulator reaches the PC through 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5080';
    }
    return 'http://127.0.0.1:5080';
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.code, [this.message]);

  final int status;

  /// Machine code from the API, e.g. invalid_otp, not_registered, slot_full.
  final String code;
  final String? message;

  bool get isUnauthorized => status == 401 && code != 'invalid_otp';

  /// Short text safe to show in the UI.
  String get friendly => switch (code) {
        'invalid_otp' => 'That code is not correct. Try again.',
        'not_registered' => 'This number is not registered yet. Please register first.',
        'already_registered' => 'This number is already registered. Please log in.',
        'invalid_phone' => 'Enter a valid 10-digit mobile number.',
        'slot_full' => 'That slot is full. Pick another time.',
        'slot_in_past' => 'That time has already passed.',
        'not_a_slot' => 'That time is not an available slot.',
        'marking_missed_disabled' => 'Marking as missed is turned off in your slot settings.',
        'registration_pending' =>
          'Your registration is being processed. Our team will contact you soon.',
        'verification_expired' => 'Verification expired. Please start again.',
        'invalid_email' => 'Enter a valid email address.',
        'social_not_configured' =>
          'This sign-in is not set up yet. Please use your mobile number.',
        'invalid_social_token' => 'Sign-in failed. Please try again.',
        'empty_message' => 'Type a message first.',
        'file_size_max_15mb' => 'The file is too big (15 MB max).',
        'file_size_max_10mb' => 'The recording is too long.',
        'phone_in_use' => 'This number is already used by another account.',
        'network' => 'Cannot reach the server. Check your connection.',
        _ => message ?? 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'ApiException($status, $code)';
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'auth_token';

  String? _token;
  http.Client _http = http.Client();

  /// Called when the server says the saved login is no longer valid.
  VoidCallback? onUnauthorized;

  String? get token => _token;
  bool get hasSession => _token != null;

  @visibleForTesting
  set httpClient(http.Client c) => _http = c;

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    } catch (_) {
      _token = null;
    }
  }

  Future<void> saveSession(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  Future<void> clearSession() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) => _send(
        () => _http.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  /// Sends a file as multipart form data (field name "file").
  Future<dynamic> upload(
    String path,
    String filePath, {
    String? fileName,
    Map<String, String> fields = const {},
  }) {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path, fields))
        ..headers.addAll({if (_token != null) 'Authorization': 'Bearer $_token'})
        ..files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
      return http.Response.fromStream(await _http.send(req));
    }, timeout: const Duration(seconds: 90));
  }

  /// Downloads a file (image, document, voice) with the login token.
  Future<List<int>> download(String path) async {
    final http.Response res;
    try {
      res = await _http.get(_uri(path), headers: _headers).timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(0, 'network');
    }
    if (res.statusCode != 200) throw ApiException(res.statusCode, 'http_${res.statusCode}');
    return res.bodyBytes;
  }

  /// Full address and login header, for images and audio streamed from the API.
  String url(String path) => '${ApiConfig.baseUrl}$path';
  Map<String, String> get authHeaders => {if (_token != null) 'Authorization': 'Bearer $_token'};

  Future<dynamic> put(String path, Object body) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> _send(
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final http.Response res;
    try {
      res = await call().timeout(timeout);
    } catch (e) {
      debugPrint('API request failed: $e');
      throw ApiException(0, 'network');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {}
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final code = data is Map && data['error'] is String ? data['error'] as String : 'http_${res.statusCode}';
    final ex = ApiException(res.statusCode, code);
    if (ex.isUnauthorized) onUnauthorized?.call();
    throw ex;
  }
}

final api = ApiClient.instance;
