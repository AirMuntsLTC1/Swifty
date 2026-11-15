// lib/ui/page/settings/settingsAndPrivacyPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/about/aboutTwitter.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/accessibility/accessibility.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/accountSettingsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/contentPrefrences/contentPreference.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/dataUsage/dataUsagePage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/displaySettings/displayAndSoundPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/notifications/notificationPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/privacyAndSafetyPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/proxy/proxyPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class SettingsAndPrivacyPage extends StatelessWidget {
  const SettingsAndPrivacyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthState>(context).userModel ?? UserModel();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SettingsAppBar(
        title: 'Settings and privacy',
        subtitle: user.userName,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SettingActionTile(
            'Account',
            subtitle: 'Login, password, sessions and your data',
            onTap: () => openSettingsPage(context, const AccountSettingsPage()),
          ),
          SettingActionTile(
            'Privacy and safety',
            subtitle: 'Who can see and contact you',
            onTap: () => openSettingsPage(context, const PrivacyAndSaftyPage()),
          ),
          SettingActionTile(
            'Notifications',
            subtitle: 'Choose what alerts you get',
            onTap: () => openSettingsPage(context, const NotificationPage()),
          ),
          SettingActionTile(
            'Content preferences',
            subtitle: 'Trends, language, blocked and muted words',
            onTap: () => openSettingsPage(context, const ContentPrefrencePage()),
          ),
          const HeaderWidget('General', secondHeader: true),
          SettingActionTile(
            'Display and sound',
            subtitle: 'Dark mode, media and sound',
            onTap: () => openSettingsPage(context, const DisplayAndSoundPage()),
          ),
          SettingActionTile(
            'Data usage',
            subtitle: 'Images, video and data saver',
            onTap: () => openSettingsPage(context, const DataUsagePage()),
          ),
          SettingActionTile(
            'Accessibility',
            subtitle: 'Reading and motion options',
            onTap: () => openSettingsPage(context, const AccessibilityPage()),
          ),
          SettingActionTile(
            'Proxy',
            subtitle: 'Route network requests through a proxy server',
            onTap: () => openSettingsPage(context, const ProxyPage()),
          ),
          SettingActionTile(
            'About Swifs',
            subtitle: 'Help, legal and the company',
            onTap: () => openSettingsPage(context, const AboutPage()),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Text(
              'Account settings follow your account on every device. Display, '
              'data, accessibility and proxy settings apply to every Swifs '
              'account on this device.',
              style: kSettingSubtitle,
            ),
          ),
        ],
      ),
    );
  }
}


