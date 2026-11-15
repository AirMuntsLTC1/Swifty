// lib/ui/page/settings/accountSettings/accessibility/accessibility.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Accessibility'),
      body: DeviceSettingsBuilder(
        builder: (context, s) => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const HeaderWidget('Screen reader'),
            SettingSwitchTile(
              title: 'Pronounce # as "hashtag"',
              value: s.pronounceHashtag,
              onChanged: (v) =>
                  DeviceSettings.instance.update('pronounce_hashtag', v),
            ),
            const HeaderWidget('Vision', secondHeader: true),
            SettingSwitchTile(
              title: 'Compose image descriptions',
              subtitle: 'Add the ability to describe images for people with low vision.',
              value: s.composeImageDescriptions,
              onChanged: (v) =>
                  DeviceSettings.instance.update('compose_image_descriptions', v),
            ),
            const HeaderWidget('Motion', secondHeader: true),
            SettingSwitchTile(
              title: 'Reduce motion',
              subtitle:
                  'Limit the amount of in-app animations, including live engagement counts.',
              value: s.reduceMotion,
              onChanged: (v) => DeviceSettings.instance.update('reduce_motion', v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
