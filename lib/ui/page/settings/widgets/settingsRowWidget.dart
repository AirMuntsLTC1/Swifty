import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/customCheckBox.dart';
import 'package:flutter_twitter_clone/widgets/url_text/customUrlText.dart';

class SettingRowWidget extends StatelessWidget {
  const SettingRowWidget(
    this.title, {
    Key? key,
    this.navigateTo,
    this.subtitle,
    this.textColor,
    this.onPressed,
    this.vPadding = 0,
    this.showDivider = true,
    this.visibleSwitch,
    this.showCheckBox,
    this.switchValue,
    this.onSwitchChanged,
  }) : super(key: key);
  final bool showDivider;
  final bool? showCheckBox, visibleSwitch;
  final String? navigateTo;
  final String? subtitle, title;
  /// Null follows the theme (black in light mode, white in dark mode).
  final Color? textColor;
  final Function? onPressed;
  final double vPadding;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
            contentPadding:
                EdgeInsets.symmetric(vertical: vPadding, horizontal: 18),
            onTap: () {
              if (onPressed != null) {
                onPressed!();
                return;
              }
              if (navigateTo == null) {
                return;
              }
              Navigator.pushNamed(context, '/$navigateTo');
            },
            title: title == null
                ? null
                : UrlText(
                    text: title ?? '',
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
            subtitle: subtitle == null
                ? null
                : UrlText(
                    text: subtitle!,
                    style: TextStyle(
                        color: TwitterColor.paleSky,
                        fontWeight: FontWeight.w400),
                  ),
            trailing: CustomCheckBox(
              isChecked: showCheckBox,
              visibleSwitch: visibleSwitch,
              switchValue: switchValue,
              onSwitchChanged: onSwitchChanged,
            )),
        !showDivider ? const SizedBox() : const Divider(height: 0)
      ],
    );
  }
}






