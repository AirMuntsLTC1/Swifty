// lib/ui/page/settings/accountSettings/privacyAndSafety/blockedAccountsPage.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/supabase/supabase_settings_tools.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';

class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({Key? key}) : super(key: key);

  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  List<Map<String, String>>? _accounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await SettingsTools.fetchBlocked();
      if (mounted) setState(() => _accounts = accounts);
    } catch (_) {
      if (mounted) setState(() => _accounts = []);
    }
  }

  Future<void> _unblock(String id, String name) async {
    try {
      await SettingsTools.unblock(id);
      if (!mounted) return;
      settingsSnack(context, 'Unblocked $name');
      _load();
    } catch (_) {
      // The repository already shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Blocked accounts'),
      body: accounts == null
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You have not blocked anyone. Accounts you block will appear here.',
                      textAlign: TextAlign.center,
                      style: kSettingSubtitle,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final account = accounts[i];
                    return ListTile(
                      contentPadding: kSettingPadding,
                      leading: ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CacheImage(
                            path: account['avatar'],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(account['name'] ?? '', style: kSettingTitle),
                      subtitle: Text(account['handle'] ?? '', style: kSettingSubtitle),
                      trailing: TextButton(
                        onPressed: () => _unblock(
                          account['id'] ?? '',
                          account['name'] ?? '',
                        ),
                        child: const Text(
                          'Unblock',
                          style: TextStyle(color: AppColor.primary),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}


