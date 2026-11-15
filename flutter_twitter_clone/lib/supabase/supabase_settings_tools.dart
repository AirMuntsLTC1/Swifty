// lib/supabase/supabase_settings_tools.dart
//
// Database helpers used by the settings screens. Each one reads or changes
// only the signed-in person's own rows (RLS enforces this too).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

class SettingsTools {
  SettingsTools._();

  static SupabaseClient get _db => SupabaseRepository.instance.db;
  static String? get _me => SupabaseRepository.instance.uid;

  /// Accounts the signed-in person has blocked, newest block first.
  /// Each map has id, name, handle and avatar.
  static Future<List<Map<String, String>>> fetchBlocked() async {
    final me = _me;
    if (me == null) return [];
    final rows = List<Map<String, dynamic>>.from(
      await _db
          .from('blocked_users')
          .select('blocked')
          .eq('blocker', me)
          .order('created_at', ascending: false),
    );
    final ids = rows.map((r) => r['blocked'].toString()).toList();
    if (ids.isEmpty) return [];

    final profiles = List<Map<String, dynamic>>.from(
      await _db
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', ids),
    );
    return profiles.map((p) {
      final username = (p['username'] ?? '').toString();
      return <String, String>{
        'id': p['id'].toString(),
        'name': (p['display_name'] ?? username).toString(),
        'handle': '@$username',
        'avatar': (p['avatar_url'] ?? '').toString(),
      };
    }).toList();
  }

  /// Removes a block so the account can see and message you again.
  static Future<void> unblock(String userId) async {
    final me = _me;
    if (me == null) return;
    await _db
        .from('blocked_users')
        .delete()
        .eq('blocker', me)
        .eq('blocked', userId);
  }

  /// Signs this person out of every other device. This session stays signed in.
  static Future<void> signOutOtherSessions() async {
    await _db.auth.signOut(scope: SignOutScope.others);
  }

  /// Gathers the person's profile, posts, connections, blocks and settings as
  /// JSON text.
  static Future<String> buildExport() async {
    final me = _me;
    if (me == null) throw StateError('Not signed in');

    final profile = await _db.from('profiles').select().eq('id', me).maybeSingle();
    final posts = await _db
        .from('posts')
        .select('id, text, audience, likes, created_at')
        .eq('author_id', me)
        .order('created_at', ascending: false);
    final following = await _db
        .from('follows')
        .select('followee, created_at')
        .eq('follower', me);
    final followers = await _db
        .from('follows')
        .select('follower, created_at')
        .eq('followee', me);
    final blocked = await _db
        .from('blocked_users')
        .select('blocked, created_at')
        .eq('blocker', me);
    final settings =
        await _db.from('user_settings').select().eq('user_id', me).maybeSingle();

    final export = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile,
      'posts': posts,
      'following': following,
      'followers': followers,
      'blocked_accounts': blocked,
      'settings': settings,
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  /// Builds the export and opens the share sheet so the person can save it.
  static Future<void> shareExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing your data...')),
    );
    try {
      final text = await buildExport();
      await Share.share(text, subject: 'My Swifs data');
    } catch (error) {
      showAppError(error, where: 'Export data');
    }
  }
}


