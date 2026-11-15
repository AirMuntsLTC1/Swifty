// lib/ui/page/settings/accountSettings/about/aboutTwitter.dart
import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/app_info.dart';
import 'package:flutter_twitter_clone/helper/open_link.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/about/companyPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/accountSettings/about/legalPage.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/headerWidget.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  void _openLegal(BuildContext context, String title, String body) {
    openSettingsPage(context, LegalPage(title: title, body: body));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: 'About Swifs'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const HeaderWidget('Help'),
          SettingActionTile(
            'Help centre',
            onTap: () => openLink(context, AppInfo.helpCentreUrl),
          ),
          const HeaderWidget('Legal'),
          SettingActionTile(
            'Terms of service',
            onTap: () => _openLegal(
                context, 'Terms of service', LegalPage.termsOfService),
          ),
          SettingActionTile(
            'Privacy policy',
            onTap: () => _openLegal(
                context, 'Privacy policy', LegalPage.privacyPolicy),
          ),
          SettingActionTile(
            'Cookie use',
            onTap: () =>
                _openLegal(context, 'Cookie use', LegalPage.cookieUse),
          ),
          SettingActionTile(
            'Legal notices',
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.appName,
              applicationVersion: AppInfo.appVersion,
              useRootNavigator: true,
            ),
          ),
          const HeaderWidget('Developer'),
          SettingActionTile(
            AppInfo.companyName,
            subtitle: 'About the company and how to contact us',
            onTap: () => openSettingsPage(context, const CompanyPage()),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '${AppInfo.appName} version ${AppInfo.appVersion}',
              style: kSettingSubtitle,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


