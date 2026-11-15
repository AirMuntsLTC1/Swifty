// lib/ui/page/settings/accountSettings/notifications/notificationPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/privacyAndSafety/mutedWordsPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
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
      appBar: const SettingsAppBar(title: 'Notifications'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Filters'),
          SettingSwitchTile(
            title: 'Quality filter',
            subtitle:
                'Filter lower-quality notifications. This will not filter out notifications from people you follow or accounts you have interacted with recently.',
            value: st.getBool('notif_quality_filter'),
            onChanged: (v) => st.setValue('notif_quality_filter', v),
          ),
          const HeaderWidget('Alerts for', secondHeader: true),
          SettingSwitchTile(
            title: 'Likes',
            value: st.getBool('notif_likes'),
            onChanged: (v) => st.setValue('notif_likes', v),
          ),
          SettingSwitchTile(
            title: 'New followers',
            value: st.getBool('notif_follows'),
            onChanged: (v) => st.setValue('notif_follows', v),
          ),
          SettingSwitchTile(
            title: 'Replies',
            value: st.getBool('notif_replies'),
            onChanged: (v) => st.setValue('notif_replies', v),
          ),
          SettingSwitchTile(
            title: 'Mentions and tags',
            value: st.getBool('notif_mentions'),
            onChanged: (v) => st.setValue('notif_mentions', v),
          ),
          SettingSwitchTile(
            title: 'Moment reactions and replies',
            value: st.getBool('notif_moments'),
            onChanged: (v) => st.setValue('notif_moments', v),
          ),
          SettingActionTile(
            'Muted words',
            subtitle: 'Hide notifications that contain these words',
            onTap: () => openSettingsPage(context, const MutedWordsPage()),
          ),
          const HeaderWidget('Preferences', secondHeader: true),
          SettingSwitchTile(
            title: 'Unread notification count badge',
            subtitle:
                'Show a badge with the number of notifications waiting for you inside the Swifs app.',
            value: st.getBool('notif_badge'),
            onChanged: (v) => st.setValue('notif_badge', v),
          ),
          SettingSwitchTile(
            title: 'Push notifications',
            value: st.getBool('push_notifications'),
            onChanged: (v) => st.setValue('push_notifications', v),
          ),
          SettingChoiceTile<String>(
            title: 'Email notifications',
            subtitle: 'How often Swifs emails you',
            value: st.getString('email_frequency'),
            options: const {
              'always': 'As they happen',
              'daily': 'Once a day',
              'never': 'Never',
            },
            onChanged: (v) => st.setValue('email_frequency', v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
