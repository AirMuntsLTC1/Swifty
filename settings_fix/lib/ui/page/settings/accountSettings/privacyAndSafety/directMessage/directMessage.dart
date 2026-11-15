// lib/ui/page/settings/accountSettings/privacyAndSafety/directMessage/directMessage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/state/settingsState.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({Key? key}) : super(key: key);

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
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
      appBar: const SettingsAppBar(title: 'Direct messages'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Requests'),
          SettingSwitchTile(
            title: 'Receive message requests from everyone',
            subtitle:
                'When this is off, only people you follow can send you messages.',
            value: st.getBool('receive_message_requests'),
            onChanged: (v) => st.setValue('receive_message_requests', v),
          ),
          SettingSwitchTile(
            title: 'Filter lower-quality messages',
            subtitle:
                'Move messages from accounts you do not follow into a separate list.',
            value: st.getBool('filter_messages'),
            onChanged: (v) => st.setValue('filter_messages', v),
          ),
          const HeaderWidget('Read receipts', secondHeader: true),
          SettingSwitchTile(
            title: 'Show read receipts',
            subtitle:
                'Let people see when you have read their messages. You will also see theirs.',
            value: st.getBool('read_receipts'),
            onChanged: (v) => st.setValue('read_receipts', v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
