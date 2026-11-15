#!/usr/bin/env python3
"""Swifly: show a clear message when the Messages list is empty.

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_messages_list.py

Safe to run twice.
"""
import pathlib
import sys

ROOT = pathlib.Path('.')
CHAT_LIST = ROOT / 'lib' / 'ui' / 'page' / 'message' / 'chatListPage.dart'
ANCHOR = ("    return ListView.separated(\n"
          "      physics: const BouncingScrollPhysics(),\n"
          "      itemCount: list.length,\n")
EMPTY_BRANCH = """    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: EmptyList(
          'No messages yet',
          subTitle:
              'Your conversations will show up here. Tap the message button to start one.',
        ),
      );
    }
"""


def fail(msg):
    sys.exit('ERROR: ' + msg)


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not (ROOT / 'lib').exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    if not CHAT_LIST.exists():
        fail('lib/ui/page/message/chatListPage.dart not found')
    text = CHAT_LIST.read_text(encoding='utf-8')
    if 'No messages yet' in text:
        print('Empty state already added.')
        return
    if text.count(ANCHOR) != 1:
        fail('list branch not found in chatListPage.dart (file changed?)')
    CHAT_LIST.write_text(text.replace(ANCHOR, EMPTY_BRANCH + ANCHOR), encoding='utf-8')
    print('Messages list: an empty conversation list now shows a message.')
    print('Done. Run the SQL migration next.')


if __name__ == '__main__':
    main()
