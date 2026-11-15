// lib/ui/page/settings/accountSettings/about/legalPage.dart
//
// Terms, privacy, cookies. The text below is a template with [bracketed]
// fields. Replace it with the text your lawyer approves before release.
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/app_info.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({Key? key, required this.title, required this.body})
      : super(key: key);

  final String title;
  final String body;

  static String get termsOfService => '''
These Terms of Service explain the rules for using ${AppInfo.appName}, provided by ${AppInfo.companyName}.

1. Accepting these terms
By creating an account or using ${AppInfo.appName}, you agree to these terms. If you do not agree, do not use the app.

2. Your account
You are responsible for keeping your sign-in details private and for everything that happens on your account.

3. Your content
You keep ownership of what you post. You give ${AppInfo.companyName} permission to store and show your content so the service works.

4. Acceptable use
Do not post illegal content, harass others, or try to access accounts or data that are not yours.

5. Changes and termination
We may update these terms or the service. We may suspend accounts that break these rules.

6. Contact
[Company legal name], [Registered address]. Contact: ${AppInfo.companyEmail.isEmpty ? '[contact email]' : AppInfo.companyEmail}
''';

  static String get privacyPolicy => '''
This Privacy Policy explains what ${AppInfo.appName} collects and how it is used. It is provided by ${AppInfo.companyName}.

1. What we collect
Account details you give us (such as username, email and profile information), the content you post, your settings, and basic device information needed to run the app.

2. How we use it
To provide the service, keep your account secure, show you content and notifications you choose, and improve the app.

3. Who can see it
Your profile and public posts are visible according to your privacy settings. Other data is visible only to you and to the service providers that run ${AppInfo.appName}.

4. Your choices
You can change most privacy and notification choices in Settings, download a copy of your data, and delete your account.

5. Data retention
We keep your data while your account is active. [Retention period for deleted data].

6. Contact
Questions about privacy: ${AppInfo.companyEmail.isEmpty ? '[privacy contact email]' : AppInfo.companyEmail}
''';

  static String get cookieUse => '''
${AppInfo.appName} does not use browser cookies in the app. Information needed to keep you signed in and to save your settings is stored securely on your device and on our servers.

[If you add a website or web features that use cookies, describe each cookie here: its name, purpose and how long it lasts.]
''';

  static String get legalNotices => '''
${AppInfo.appName} is provided by ${AppInfo.companyName}.

Open-source software used in this app is listed under "Legal notices" in the About Swifs page.

[Trademark and copyright notice for ${AppInfo.companyName} and ${AppInfo.appName}.]
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SettingsAppBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Text(
          body,
          style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.black),
        ),
      ),
    );
  }
}
