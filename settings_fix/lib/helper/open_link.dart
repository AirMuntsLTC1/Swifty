// lib/helper/open_link.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';

/// Opens [url] in the in-app browser or the phone's browser, depending on the
/// "Use in-app browser" setting. Shows a message when the link is empty.
Future<void> openLink(BuildContext context, String url) async {
  final clean = url.trim();
  final messenger = ScaffoldMessenger.of(context);
  if (clean.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This link is not set yet.')),
    );
    return;
  }
  final mode = DeviceSettings.instance.inAppBrowser
      ? LaunchMode.inAppWebView
      : LaunchMode.externalApplication;
  final opened = await launchUrl(Uri.parse(clean), mode: mode);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
  }
}
