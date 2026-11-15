// lib/ui/page/settings/accountSettings/dataUsage/dataUsagePage.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class DataUsagePage extends StatelessWidget {
  const DataUsagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsAppBar(title: 'Data usage'),
      body: DeviceSettingsBuilder(
        builder: (context, s) => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const HeaderWidget('Data saver'),
            SettingSwitchTile(
              title: 'Data saver',
              subtitle:
                  'When enabled, lower-quality images load. This reduces your data usage for all Swifs accounts on this device.',
              value: s.dataSaver,
              onChanged: (v) => DeviceSettings.instance.update('data_saver', v),
            ),
            const HeaderWidget('Images', secondHeader: true),
            SettingChoiceTile<String>(
              title: 'High quality images',
              subtitle: 'When high quality images should load',
              value: s.imageQuality,
              options: const {
                'always': 'Mobile data and Wi-Fi',
                'wifi': 'Wi-Fi only',
                'never': 'Never',
              },
              onChanged: (v) => DeviceSettings.instance.update('image_quality', v),
            ),
            const HeaderWidget('Video', secondHeader: true),
            SettingChoiceTile<String>(
              title: 'High-quality video',
              subtitle: 'When the highest quality available should play',
              value: s.videoQuality,
              options: const {
                'wifi': 'Wi-Fi only',
                'always': 'Mobile data and Wi-Fi',
                'never': 'Never',
              },
              onChanged: (v) => DeviceSettings.instance.update('video_quality', v),
            ),
            SettingChoiceTile<String>(
              title: 'Video autoplay',
              subtitle: 'When video should play automatically',
              value: s.videoAutoplay,
              options: const {
                'wifi': 'Wi-Fi only',
                'always': 'Mobile data and Wi-Fi',
                'never': 'Never',
              },
              onChanged: (v) => DeviceSettings.instance.update('video_autoplay', v),
            ),
            const HeaderWidget('Data sync', secondHeader: true),
            SettingSwitchTile(
              title: 'Sync data',
              subtitle:
                  'Allow Swifs to sync data in the background to enhance your experience.',
              value: s.syncData,
              onChanged: (v) => DeviceSettings.instance.update('sync_data', v),
            ),
            SettingChoiceTile<String>(
              title: 'Sync interval',
              value: s.syncInterval,
              options: const {
                'hourly': 'Every hour',
                'daily': 'Daily',
                'weekly': 'Weekly',
              },
              onChanged: (v) => DeviceSettings.instance.update('sync_interval', v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}




