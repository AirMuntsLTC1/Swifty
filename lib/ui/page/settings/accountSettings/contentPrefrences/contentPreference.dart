// lib/ui/page/settings/accountSettings/contentPrefrences/contentPreference.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/contentPrefrences/trends/trendsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/blockedAccountsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/mutedWordsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class ContentPrefrencePage extends StatefulWidget {
  const ContentPrefrencePage({Key? key}) : super(key: key);

  @override
  State<ContentPrefrencePage> createState() => _ContentPrefrencePageState();
}

class _ContentPrefrencePageState extends State<ContentPrefrencePage> {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Content preferences'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Explore'),
          SettingActionTile(
            'Trends',
            subtitle: 'Choose the place your trends come from',
            onTap: () => openSettingsPage(context, const TrendsPage()),
          ),
          const HeaderWidget('Language', secondHeader: true),
          SettingChoiceTile<String>(
            title: 'Recommendations language',
            subtitle: 'Recommended posts, people and trends in this language',
            value: st.getString('content_language'),
            options: const {
              'English': 'English',
              'Indonesian': 'Indonesian',
              'Spanish': 'Spanish',
              'French': 'French',
              'German': 'German',
              'Portuguese': 'Portuguese',
              'Other': 'Other',
            },
            onChanged: (v) => st.setValue('content_language', v),
          ),
          const HeaderWidget('Safety', secondHeader: true),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
