// lib/ui/page/settings/accountSettings/privacyAndSafety/privacyAndSafetyPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_settings_tools.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/blockedAccountsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/directMessage/directMessage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/mutedWordsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class PrivacyAndSaftyPage extends StatefulWidget {
  const PrivacyAndSaftyPage({Key? key}) : super(key: key);

  @override
  State<PrivacyAndSaftyPage> createState() => _PrivacyAndSaftyPageState();
}

class _PrivacyAndSaftyPageState extends State<PrivacyAndSaftyPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<SettingsState>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsState>();
    final user = Provider.of<AuthState>(context).userModel ?? UserModel();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SettingsAppBar(
        title: 'Privacy and safety',
        subtitle: user.userName,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Posts'),
          SettingSwitchTile(
            title: 'Protect your posts',
            subtitle:
                'Only current followers and people you approve in future will be able to see your posts.',
            value: st.getBool('protected'),
            onChanged: (v) => st.setValue('protected', v),
          ),
          SettingChoiceTile<String>(
            title: 'Photo tagging',
            value: st.getString('photo_tagging'),
            options: const {
              'everyone': 'Anyone can tag you',
              'followers': 'Only people you follow can tag you',
              'none': 'No one can tag you',
            },
            onChanged: (v) => st.setValue('photo_tagging', v),
          ),
          const HeaderWidget('Messages', secondHeader: true),
          SettingActionTile(
            'Direct messages',
            subtitle: 'Message requests and read receipts',
            onTap: () => openSettingsPage(context, const DirectMessagesPage()),
          ),
          const HeaderWidget('Blocking and muting', secondHeader: true),
          SettingActionTile(
            'Blocked accounts',
            subtitle: 'Accounts you have blocked',
            onTap: () => openSettingsPage(context, const BlockedAccountsPage()),
          ),
          SettingActionTile(
            'Muted words',
            subtitle: 'Hide notifications that contain these words',
            onTap: () => openSettingsPage(context, const MutedWordsPage()),
          ),
          const HeaderWidget('Safety', secondHeader: true),
          SettingSwitchTile(
            title: 'Display media that may contain sensitive content',
            value: st.getBool('sensitive_media_display'),
            onChanged: (v) => st.setValue('sensitive_media_display', v),
          ),
          SettingSwitchTile(
            title: 'Mark media you post as containing material that may be sensitive',
            value: st.getBool('sensitive_media_mark'),
            onChanged: (v) => st.setValue('sensitive_media_mark', v),
          ),
          const HeaderWidget('Live video', secondHeader: true),
          SettingSwitchTile(
            title: 'Live video',
            subtitle:
                'Let people go live and comment on your broadcasts, and show when you are watching.',
            value: st.getBool('live_video'),
            onChanged: (v) => st.setValue('live_video', v),
          ),
          const HeaderWidget('Location', secondHeader: true),
          SettingSwitchTile(
            title: 'Precise location',
            subtitle:
                'If enabled, Swifs will use your device’s precise location, such as GPS, to show you more local content, ads and recommendations.',
            value: st.getBool('precise_location'),
            onChanged: (v) => st.setValue('precise_location', v),
          ),
          const HeaderWidget('Personalisation and data', secondHeader: true),
          SettingChoiceTile<String>(
            title: 'Personalisation and data',
            value: st.getString('personalisation'),
            options: const {
              'all': 'Allow all',
              'limited': 'Limited',
              'none': 'Do not personalise',
            },
            onChanged: (v) => st.setValue('personalisation', v),
          ),
          SettingActionTile(
            'See your Swifs data',
            subtitle:
                'Review and download your profile information and data associated with your account',
            onTap: () => SettingsTools.shareExport(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


