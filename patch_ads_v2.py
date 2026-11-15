#!/usr/bin/env python3
"""Swifly ads v2: AdMob package and manifest App ID.

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_ads_v2.py

Reads kAdMobAppIdAndroid from lib/config/ads_config.dart and writes it to
android/app/src/main/AndroidManifest.xml. Safe to run again after you change
the config.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path('.')
PUBSPEC = ROOT / 'pubspec.yaml'
CONFIG = ROOT / 'lib' / 'config' / 'ads_config.dart'
MANIFEST = ROOT / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
ADMOB_PACKAGE = 'google_mobile_ads'
ADMOB_VERSION = '^5.1.0'
META_NAME = 'com.google.android.gms.ads.APPLICATION_ID'


def fail(msg):
    sys.exit('ERROR: ' + msg)


def patch_pubspec():
    text = PUBSPEC.read_text(encoding='utf-8')
    if re.search(rf'^\s*{ADMOB_PACKAGE}:', text, re.M):
        print('  google_mobile_ads already in pubspec.yaml')
        return
    m = re.search(r'^dependencies:\s*\n', text, re.M)
    if not m:
        fail('dependencies: block not found in pubspec.yaml')
    text = text[:m.end()] + f'  {ADMOB_PACKAGE}: {ADMOB_VERSION}\n' + text[m.end():]
    PUBSPEC.write_text(text, encoding='utf-8')
    print(f'  added {ADMOB_PACKAGE} {ADMOB_VERSION} to pubspec.yaml')


def app_id_from_config():
    text = CONFIG.read_text(encoding='utf-8')
    m = re.search(r"kAdMobAppIdAndroid\s*=\s*'([^']+)'", text)
    if not m:
        fail('kAdMobAppIdAndroid not found in lib/config/ads_config.dart')
    return m.group(1)


def patch_manifest(app_id):
    if not MANIFEST.exists():
        fail('android/app/src/main/AndroidManifest.xml not found')
    text = MANIFEST.read_text(encoding='utf-8')
    meta = (f'        <meta-data\n'
            f'            android:name="{META_NAME}"\n'
            f'            android:value="{app_id}"/>\n')
    pattern = re.compile(
        r'<meta-data\s+android:name="' + re.escape(META_NAME) +
        r'"\s+android:value="[^"]*"\s*/>', re.S)
    if pattern.search(text):
        text = pattern.sub(
            f'<meta-data android:name="{META_NAME}" android:value="{app_id}"/>',
            text, count=1)
        print('  AdMob App ID updated in AndroidManifest.xml')
    else:
        if text.count('</application>') != 1:
            fail('</application> not found exactly once in AndroidManifest.xml')
        text = text.replace('</application>', meta + '    </application>')
        print('  AdMob App ID added to AndroidManifest.xml')
    MANIFEST.write_text(text, encoding='utf-8')


def main():
    if not PUBSPEC.exists() or not (ROOT / 'lib').exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    for path in [CONFIG, ROOT / 'lib' / 'widgets' / 'ads' / 'admob_native_slot.dart']:
        if not path.exists():
            fail(f'{path} is missing. Unzip the whole archive first.')
    print('1/2 AdMob package')
    patch_pubspec()
    print('2/2 Android App ID')
    patch_manifest(app_id_from_config())
    print('Done. Next: run the SQL migration, then build. Replace the test IDs in')
    print('lib/config/ads_config.dart with your real Swifly IDs before release.')


if __name__ == '__main__':
    main()
