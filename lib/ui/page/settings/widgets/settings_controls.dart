// lib/ui/page/settings/widgets/settings_controls.dart
//
// Shared rows and dialogs for every settings screen, so they all look and
// behave the same.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/state/deviceSettings.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

const TextStyle kSettingTitle = TextStyle(fontSize: 16, color: Colors.black);
const TextStyle kSettingSubtitle =
    TextStyle(fontSize: 13, color: AppColor.darkGrey);
const EdgeInsets kSettingPadding = EdgeInsets.symmetric(horizontal: 18);

/// Right-pointing arrow for rows that open a page. Rotates the app's
/// chevronDown icon so it only needs icons the app already uses.
Widget settingsChevron() {
  // Not const: Transform.rotate is not a const constructor.
  return SizedBox(
    width: 20,
    height: 20,
    child: Center(
      child: Transform.rotate(
        angle: -math.pi / 2,
        child: const Icon(LucideIcons.chevronDown,
            color: AppColor.darkGrey, size: 20),
      ),
    ),
  );
}

/// Opens a settings sub-page.
void openSettingsPage(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
}

void settingsSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// On/off row.
class SettingSwitchTile extends StatelessWidget {
  const SettingSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: kSettingPadding.copyWith(top: 4, bottom: 4),
      activeColor: AppColor.primary,
      title: Text(title, style: kSettingTitle),
      subtitle: subtitle == null ? null : Text(subtitle!, style: kSettingSubtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Row that opens a list of options in a dialog. Shows the current choice.
class SettingChoiceTile<T> extends StatelessWidget {
  const SettingChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: kSettingPadding.copyWith(top: 6, bottom: 6),
      title: Text(title, style: kSettingTitle),
      subtitle: Text(
        subtitle != null ? '$subtitle\n${options[value] ?? ''}' : (options[value] ?? ''),
        style: kSettingSubtitle,
      ),
      trailing: settingsChevron(),
      onTap: () async {
        final picked = await showChoiceDialog<T>(
          context,
          title: title,
          value: value,
          options: options,
        );
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

/// Row that opens a text box in a dialog. Shows the current text.
class SettingTextTile extends StatelessWidget {
  const SettingTextTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.emptyText = 'Not set',
  });

  final String title;
  final String value;
  final String? hint;
  final TextInputType? keyboardType;
  final String emptyText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: kSettingPadding.copyWith(top: 6, bottom: 6),
      title: Text(title, style: kSettingTitle),
      subtitle: Text(value.isEmpty ? emptyText : value, style: kSettingSubtitle),
      trailing: settingsChevron(),
      onTap: () async {
        final typed = await showTextInputDialog(
          context,
          title: title,
          initial: value,
          hint: hint,
          keyboardType: keyboardType,
        );
        if (typed != null && typed != value) onChanged(typed);
      },
    );
  }
}

/// Row that runs an action when tapped.
class SettingActionTile extends StatelessWidget {
  const SettingActionTile(
    this.title, {
    super.key,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: kSettingPadding.copyWith(top: 6, bottom: 6),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: destructive ? TwitterColor.ceriseRed : Colors.black,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!, style: kSettingSubtitle),
      trailing: showChevron
          ? settingsChevron()
          : null,
      onTap: onTap,
    );
  }
}

/// Read-only row (for example the username or email).
class SettingInfoTile extends StatelessWidget {
  const SettingInfoTile(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: kSettingPadding.copyWith(top: 6, bottom: 6),
      title: Text(title, style: kSettingTitle),
      subtitle: Text(
        (subtitle == null || subtitle!.isEmpty) ? 'Not set' : subtitle!,
        style: kSettingSubtitle,
      ),
    );
  }
}

/// Rebuilds when this device's settings change.
class DeviceSettingsBuilder extends StatelessWidget {
  const DeviceSettingsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DeviceSettings settings) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DeviceSettings.instance,
      builder: (context, _) => builder(context, DeviceSettings.instance),
    );
  }
}

Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required T value,
  required Map<T, String> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in options.entries)
              RadioListTile<T>(
                value: entry.key,
                groupValue: value,
                activeColor: AppColor.primary,
                title: Text(entry.value),
                onChanged: (picked) => Navigator.pop(ctx, picked),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
  TextInputType? keyboardType,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save',
              style: TextStyle(color: AppColor.primary)),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: kSettingSubtitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? TwitterColor.ceriseRed : AppColor.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}


