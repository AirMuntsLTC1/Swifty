import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/config/supabase_config.dart';

/// A user-facing authentication error (message is safe to show in the UI).
class SwiflyAuthError implements Exception {
  SwiflyAuthError(this.message, {this.retryAfter});

  final String message;
  final int? retryAfter;

  @override
  String toString() => message;
}

/// Talks to the custom `email-code-auth` Edge Function and keeps the
/// Supabase client session in sync with the session it returns.
class SupabaseAuthService {
  SupabaseAuthService._();

  static final SupabaseAuthService instance = SupabaseAuthService._();

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'Supabase not configured: set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
      return;
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    if (!SupabaseConfig.isConfigured) {
      throw SwiflyAuthError(
        'Supabase is not configured yet. Add your project URL and anon key.',
      );
    }
    try {
      final res = await _client.functions.invoke(
        SupabaseConfig.authFunction,
        body: body,
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      throw SwiflyAuthError('Unexpected response from the server.');
    } on SwiflyAuthError {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      var message = 'Something went wrong. Please try again.';
      int? retry;
      if (details is Map) {
        final err = details['error'];
        if (err != null) message = err.toString();
        final r = details['retry_after'];
        if (r is num) retry = r.toInt();
      } else if (details is String && details.isNotEmpty) {
        message = details;
      }
      throw SwiflyAuthError(message, retryAfter: retry);
    } catch (_) {
      throw SwiflyAuthError('Network error. Check your connection and try again.');
    }
  }

  /// Stores the session returned by the Edge Function in the Supabase client,
  /// so the app is signed in and auth.currentSession works everywhere.
  Future<void> _adoptSession(Map<String, dynamic> data) async {
    final session = data['session'];
    if (session is Map && session['refresh_token'] is String) {
      await _client.auth.setSession(session['refresh_token'] as String);
    }
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _call({
      'action': 'login',
      'email': email,
      'password': password,
    });
    await _adoptSession(data);
  }

  /// Sends a 6-digit code. Returns the number of seconds before a resend is allowed.
  Future<int> sendCode({
    required String email,
    required String purpose, // 'signup' or 'password_reset'
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    final data = await _call({
      'action': 'send_code',
      'email': email,
      'purpose': purpose,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });
    final resend = data['resend_after'];
    return resend is num ? resend.toInt() : 60;
  }

  Future<void> checkCode({
    required String email,
    required String code,
    required String purpose,
  }) async {
    await _call({
      'action': 'check_code',
      'email': email,
      'code': code,
      'purpose': purpose,
    });
  }

  /// Creates the account after the sign-up code was verified, then signs in.
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    final data = await _call({
      'action': 'create_account',
      'email': email,
      'password': password,
    });
    await _adoptSession(data);
  }

  /// Sets a new password after the reset code was verified, then signs in.
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    final data = await _call({
      'action': 'reset_password',
      'email': email,
      'password': password,
    });
    await _adoptSession(data);
  }

  Future<void> signOut() => _client.auth.signOut();
}




