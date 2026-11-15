// lib/ui/page/settings/accountSettings/displaySettings/displayAndSoundPage.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class DisplayAndSoundPage extends StatelessWidget {
  const DisplayAndSoundPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Display and sound'),
      body: DeviceSettingsBuilder(
        builder: (context, s) => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const HeaderWidget('Media'),
            SettingSwitchTile(
              title: 'Media previews',
              subtitle: 'Show a preview of photos and links before you open them.',
              value: s.mediaPreviews,
              onChanged: (v) => DeviceSettings.instance.update('media_previews', v),
            ),
            const HeaderWidget('Display', secondHeader: true),
            SettingChoiceTile<String>(
              title: 'Dark mode',
              value: s.darkModeChoice,
              options: const {
                'light': 'Off',
                'dark': 'On',
                'system': 'Use device setting',
              },
              onChanged: (v) => DeviceSettings.instance.update('dark_mode', v),
            ),
            SettingChoiceTile<String>(
              title: 'Dark mode appearance',
              subtitle: 'Used when dark mode is on',
              value: s.darkAppearance,
              options: const {
                'dim': 'Dim',
                'lights_out': 'Lights out',
              },
              onChanged: (v) => DeviceSettings.instance.update('dark_appearance', v),
            ),
            const HeaderWidget('Sound', secondHeader: true),
            SettingSwitchTile(
              title: 'Sound effects',
              value: s.soundEffects,
              onChanged: (v) => DeviceSettings.instance.update('sound_effects', v),
            ),
            const HeaderWidget('Web browser', secondHeader: true),
            SettingSwitchTile(
              title: 'Use in-app browser',
              subtitle: 'Open links inside Swifs instead of your browser app.',
              value: s.inAppBrowser,
              onChanged: (v) => DeviceSettings.instance.update('in_app_browser', v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
