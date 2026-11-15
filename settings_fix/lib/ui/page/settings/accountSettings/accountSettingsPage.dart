// lib/ui/page/settings/accountSettings/accountSettingsPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/supabase/screens/forgot_password_page.dart';
import 'package:flutter_twitter_clone/supabase/supabase_settings_tools.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

const List<String> kCountries = [
  'Canada',
  'Australia',
  'United Kingdom',
  'United States',
  'Nigeria',
  'Kenya',
  'South Africa',
  'India',
  'Indonesia',
  'Philippines',
  'Brazil',
  'Germany',
  'France',
  'Other',
];

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<SettingsState>().ensureLoaded();
    });
  }

  Future<void> _signOutOthers() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out other devices?',
      message:
          'You will stay signed in here. Swifs will be signed out on every other device.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    try {
      await SettingsTools.signOutOtherSessions();
      if (mounted) settingsSnack(context, 'Signed out on other devices.');
    } catch (error) {
      showAppError(error, where: 'Sign out other devices');
    }
  }

  Future<void> _logOut() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Log out of Swifs?',
      message: 'You will need to sign in again to use your account here.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok || !mounted) return;
    Navigator.popUntil(context, ModalRoute.withName('/'));
    final state = Provider.of<AuthState>(context, listen: false);
    state.logoutCallback();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthState>(context).userModel ?? UserModel();
    final settings = context.watch<SettingsState>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SettingsAppBar(title: 'Account', subtitle: user.userName),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Login and security'),
          SettingInfoTile('Username', subtitle: user.userName),
          SettingInfoTile('Phone', subtitle: user.contact),
          SettingInfoTile('Email address', subtitle: user.email),
          SettingActionTile(
            'Password',
            subtitle: 'Get a code by email and choose a new password',
            onTap: () => openSettingsPage(context, const ForgotPasswordPage()),
          ),
          SettingActionTile(
            'Apps and sessions',
            subtitle: 'Sign out of Swifs on your other devices',
            onTap: _signOutOthers,
          ),
          const HeaderWidget('Data and permission', secondHeader: true),
          SettingChoiceTile<String>(
            title: 'Country',
            value: settings.getString('country'),
            options: {
              '': 'Not set',
              for (final country in kCountries) country: country,
            },
            onChanged: (v) => settings.setValue('country', v),
          ),
          SettingActionTile(
            'Your Swifs data',
            subtitle: 'Download a copy of your profile, posts and connections',
            onTap: () => SettingsTools.shareExport(context),
          ),
          SettingActionTile(
            'Log out',
            destructive: true,
            showChevron: false,
            onTap: _logOut,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
