#!/usr/bin/env python3
"""Swifly: real animated verified badge + chat keyboard framedrop fix.

Run from the project root (the folder that contains pubspec.yaml and lib/):
    python3 patch_verified_and_keyboard.py

Safe to run twice: code that is already patched is skipped.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path('.')
LIB = ROOT / 'lib'
BADGE_CALL = 'AppIcon.blueTick'
BADGE_IMPORT = "import 'package:flutter_twitter_clone/widgets/verified_badge.dart';\n"

CHAT_OLD = """        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: _chatScreenBody(),
                ),
              ),
              _bottomEntryField()
            ],
          ),
        ),
"""

CHAT_NEW = """        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: _chatBodyStack(),
        ),
"""

CHAT_ANCHOR = "  Future<bool> _onWillPop() async {\n"

CHAT_METHOD = """  /// Keyboard-safe layout. The Scaffold does not resize on each keyboard
  /// frame. Only a small Builder reads the keyboard height, and the message
  /// list and composer are built once, so they are not rebuilt every frame.
  Widget _chatBodyStack() {
    final messages = RepaintBoundary(child: _chatScreenBody());
    final composer = RepaintBoundary(child: _bottomEntryField());
    return Builder(
      builder: (context) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: 50 + keyboard),
                child: messages,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboard,
              child: composer,
            ),
          ],
        );
      },
    );
  }

"""


def fail(msg):
    sys.exit('ERROR: ' + msg)


def swap_badge_calls(text):
    """Replace each customIcon(... AppIcon.blueTick ...) call with VerifiedBadge."""
    out, pos, count = [], 0, 0
    while True:
        start = text.find('customIcon(', pos)
        if start == -1:
            break
        depth, i = 0, start + len('customIcon')
        while i < len(text):
            if text[i] == '(':
                depth += 1
            elif text[i] == ')':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        call = text[start:i + 1]
        out.append(text[pos:start])
        if BADGE_CALL in call:
            size = re.search(r'size:\s*([0-9.]+)', call)
            out.append('VerifiedBadge(size: %s)' % (size.group(1) if size else '14'))
            count += 1
        else:
            out.append(call)
        pos = i + 1
    out.append(text[pos:])
    return ''.join(out), count


def add_import(text):
    if BADGE_IMPORT in text:
        return text
    m = re.search(r'^import .*;\n', text, re.M)
    if not m:
        fail('no import line found to attach the badge import to')
    return text[:m.start()] + BADGE_IMPORT + text[m.start():]


def patch_badges():
    total, files = 0, 0
    for path in sorted(LIB.rglob('*.dart')):
        if path.name == 'verified_badge.dart':
            continue
        text = path.read_text(encoding='utf-8')
        if BADGE_CALL not in text:
            continue
        new, n = swap_badge_calls(text)
        if n == 0:
            print(f'  WARNING: {path} mentions {BADGE_CALL} but no call was replaced')
            continue
        path.write_text(add_import(new), encoding='utf-8')
        total += n
        files += 1
        print(f'  {n} badge(s) -> {path}')
    print(f'  Verified badge: {total} call sites in {files} files (0 means already done).')


def patch_repository():
    path = LIB / 'supabase' / 'supabase_repository.dart'
    text = path.read_text(encoding='utf-8')
    if "row['is_verified'] == true" not in text:
        old = "      isVerified: false,\n      bannerImage: (row['cover_url']"
        if text.count(old) != 1:
            fail('mapProfile block not found in supabase_repository.dart')
        text = text.replace(
            old,
            "      isVerified: row['is_verified'] == true,\n      bannerImage: (row['cover_url']",
        )
    path.write_text(text, encoding='utf-8')
    sel_old = "'id, username, display_name, avatar_url'"
    sel_new = "'id, username, display_name, avatar_url, is_verified'"
    total = 0
    for other in sorted(LIB.rglob('*.dart')):
        src = other.read_text(encoding='utf-8')
        if sel_old in src:
            total += src.count(sel_old)
            other.write_text(src.replace(sel_old, sel_new), encoding='utf-8')
    print(f'  mapProfile reads is_verified; {total} profile select lists now include it.')


def patch_chat():
    path = LIB / 'ui' / 'page' / 'message' / 'chatScreenPage.dart'
    text = path.read_text(encoding='utf-8')
    if '_chatBodyStack()' in text:
        print('  chat keyboard fix already applied.')
        return
    if text.count(CHAT_OLD) != 1:
        fail('chat body block not found in chatScreenPage.dart (file changed?)')
    if text.count(CHAT_ANCHOR) != 1:
        fail('insertion anchor not found in chatScreenPage.dart')
    text = text.replace(CHAT_OLD, CHAT_NEW).replace(CHAT_ANCHOR, CHAT_METHOD + CHAT_ANCHOR)
    path.write_text(text, encoding='utf-8')
    print('  chat composer no longer resizes with the keyboard; list and composer are isolated.')


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not LIB.exists():
        fail('run this from the project root (the folder with pubspec.yaml and lib/)')
    if not (LIB / 'widgets' / 'verified_badge.dart').exists():
        fail('lib/widgets/verified_badge.dart is missing. Unzip the whole archive into the project first.')
    print('1/3 Verified badge call sites')
    patch_badges()
    print('2/3 Profile data (is_verified)')
    patch_repository()
    print('3/3 Chat keyboard framedrops')
    patch_chat()
    print('Done. Next: run the SQL migration in Supabase SQL Editor, then build the APK.')


if __name__ == '__main__':
    main()
