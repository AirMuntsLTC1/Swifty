// lib/ui/page/settings/accountSettings/about/companyPage.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/helper/app_info.dart';
import 'package:flutter_twitter_clone/helper/open_link.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settingsAppbar.dart';
import 'package:flutter_twitter_clone/ui/page/settings/widgets/settings_controls.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

class CompanyPage extends StatelessWidget {
  const CompanyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const SettingsAppBar(title: AppInfo.companyName),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColor.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  AppInfo.companyName.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppInfo.companyName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            AppInfo.companyDescription,
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contact',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColor.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          _ContactButton(
            icon: LucideIcons.link,
            label: 'Visit our website',
            onTap: () => openLink(context, AppInfo.companyWebsite),
          ),
          _ContactButton(
            icon: LucideIcons.mail,
            label: 'Email us',
            onTap: () => openLink(
              context,
              AppInfo.companyEmail.isEmpty ? '' : 'mailto:${AppInfo.companyEmail}',
            ),
          ),
          _ContactButton(
            icon: LucideIcons.info,
            label: 'Help centre',
            onTap: () => openLink(context, AppInfo.helpCentreUrl),
          ),
          const SizedBox(height: 24),
          Text(
            '${AppInfo.appName} version ${AppInfo.appVersion}',
            style: kSettingSubtitle,
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xffEFF3F4)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColor.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


