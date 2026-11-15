// lib/helper/proxy_overrides.dart
import 'dart:io';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';

/// Sends network requests through the proxy set in Settings > Proxy.
/// Connections opened after a change use the new proxy. Restart Swifs after
/// changing it so every connection picks it up.
class ProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final settings = DeviceSettings.instance;
    final host = settings.proxyHost.trim();
    if (settings.proxyEnabled && host.isNotEmpty) {
      final target = '$host:${settings.proxyPort}';
      client.findProxy = (uri) => 'PROXY $target';
    }
    return client;
  }
}




