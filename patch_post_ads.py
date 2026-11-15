#!/usr/bin/env python3
"""Swifly: ads that look like posts, and visible empty states.

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_post_ads.py

1. Registers the post-style AdMob layout in MainActivity.kt.
2. Messages and Notifications show their empty-state text (plain Text).

Safe to run twice.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path('.')
LIB = ROOT / 'lib'
ACTIVITY = (ROOT / 'android' / 'app' / 'src' / 'main' / 'kotlin' /
            'com' / 'thealphamerc' / 'flutter_twitter_clone' / 'MainActivity.kt')
EMPTY_IMPORT = "import 'package:flutter_twitter_clone/widgets/newWidget/app_empty_state.dart';\n"
EMPTY_FILES = [
    LIB / 'ui' / 'page' / 'message' / 'chatListPage.dart',
    LIB / 'ui' / 'page' / 'notification' / 'notificationPage.dart',
]
REQUIRED = [
    ACTIVITY.parent / 'NativePostAdFactory.kt',
    ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / 'layout' / 'native_post_ad.xml',
    LIB / 'widgets' / 'newWidget' / 'app_empty_state.dart',
    LIB / 'widgets' / 'ads' / 'admob_native_slot.dart',
]


def fail(msg):
    sys.exit('ERROR: ' + msg)


def add_import(text, line):
    if line in text:
        return text
    idx = text.index('\nimport ') + 1
    end = text.index('\n', idx) + 1
    return text[:end] + line + text[end:]


def patch_activity():
    text = ACTIVITY.read_text(encoding='utf-8')
    if 'swiflyPostAd' in text:
        print('  MainActivity: post ad layout already registered')
        return
    gm_import = 'import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin\n'
    anchor_import = 'import io.flutter.plugin.common.MethodChannel\n'
    if text.count(anchor_import) != 1:
        fail('MethodChannel import not found in MainActivity.kt')
    text = text.replace(anchor_import, anchor_import + gm_import)

    anchor_config = '        super.configureFlutterEngine(flutterEngine)\n'
    if text.count(anchor_config) != 1:
        fail('configureFlutterEngine not found in MainActivity.kt')
    text = text.replace(anchor_config, anchor_config +
        '        GoogleMobileAdsPlugin.registerNativeAdFactory(\n'
        '            flutterEngine,\n'
        '            "swiflyPostAd",\n'
        '            NativePostAdFactory(this)\n'
        '        )\n')

    anchor_fn = '    private fun createNotificationChannel() {\n'
    if text.count(anchor_fn) != 1:
        fail('createNotificationChannel not found in MainActivity.kt')
    text = text.replace(anchor_fn,
        '    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {\n'
        '        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "swiflyPostAd")\n'
        '        super.cleanUpFlutterEngine(flutterEngine)\n'
        '    }\n\n' + anchor_fn)
    ACTIVITY.write_text(text, encoding='utf-8')
    print('  MainActivity: post ad layout registered')


def patch_empty_states():
    for path in EMPTY_FILES:
        if not path.exists():
            fail(f'{path} not found')
        text = path.read_text(encoding='utf-8')
        if 'AppEmptyState(' in text:
            print(f'  {path.name}: already uses AppEmptyState')
            continue
        count = len(re.findall(r'\bEmptyList\(', text))
        if count == 0:
            fail(f'no EmptyList in {path.name}; check the file')
        text = re.sub(r'\bEmptyList\(', 'AppEmptyState(', text)
        text = add_import(text, EMPTY_IMPORT)
        path.write_text(text, encoding='utf-8')
        print(f'  {path.name}: {count} empty state(s) now use AppEmptyState')


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not LIB.exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    if not ACTIVITY.exists():
        fail('MainActivity.kt not found')
    missing = [str(p) for p in REQUIRED if not p.exists()]
    if missing:
        fail('missing files, unzip the whole archive first: ' + ', '.join(missing))
    print('1/2 Post-style AdMob layout')
    patch_activity()
    print('2/2 Empty states (Messages, Notifications)')
    patch_empty_states()
    print('Done. Build the APK next.')


if __name__ == '__main__':
    main()
