// lib/ui/page/settings/accountSettings/proxy/proxyPage.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class ProxyPage extends StatelessWidget {
  const ProxyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'Proxy'),
      body: DeviceSettingsBuilder(
        builder: (context, s) => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            SettingSwitchTile(
              title: 'Enable HTTP proxy',
              subtitle:
                  'Send Swifs network requests through this proxy. Restart Swifs after changing it. This does not apply to the in-app browser.',
              value: s.proxyEnabled,
              onChanged: (v) => DeviceSettings.instance.update('proxy_enabled', v),
            ),
            SettingTextTile(
              title: 'Proxy host',
              value: s.proxyHost,
              hint: 'For example 192.168.1.10',
              emptyText: 'Not set. Enter the proxy hostname.',
              onChanged: (v) => DeviceSettings.instance.update('proxy_host', v),
            ),
            SettingTextTile(
              title: 'Proxy port',
              value: s.proxyPort.toString(),
              hint: 'For example 8080',
              keyboardType: TextInputType.number,
              emptyText: '8080',
              onChanged: (v) {
                final port = int.tryParse(v);
                if (port != null && port > 0 && port < 65536) {
                  DeviceSettings.instance.update('proxy_port', port);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
