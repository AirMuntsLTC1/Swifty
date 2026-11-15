#!/usr/bin/env python3
"""Swifly: delete conversations + empty-chat profile intro.

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_delete_conversations.py

Safe to run twice. Requires the new files from this archive to be unzipped first.
"""
import pathlib
import sys

ROOT = pathlib.Path('.')
LIB = ROOT / 'lib'
MSG = LIB / 'ui' / 'page' / 'message'
STATE = LIB / 'state' / 'chats' / 'chatState.dart'
SCREEN = MSG / 'chatScreenPage.dart'

REQUIRED_NEW = [
    LIB / 'supabase' / 'supabase_chat_delete.dart',
    MSG / 'widgets' / 'conversation_intro.dart',
    MSG / 'chatListPage.dart',
]


def fail(msg):
    sys.exit('ERROR: ' + msg)


def add_import(text, line):
    if line in text:
        return text
    idx = text.index('\nimport ') + 1 if '\nimport ' in text else 0
    end = text.index('\n', idx) + 1
    return text[:end] + line + '\n' + text[end:]


def patch_state():
    text = STATE.read_text(encoding='utf-8')
    if 'fetchHiddenMessageIds' in text:
        print('  chatState already patched')
        return
    text = add_import(text, "import 'package:flutter_twitter_clone/supabase/supabase_chat_delete.dart';")

    inbox_old = 'final rows = await _repo.fetchInboxRows(userId);'
    inbox_new = ('final hidden = await _repo.fetchHiddenMessageIds(userId);\n'
                 '      final rows = (await _repo.fetchInboxRows(userId))\n'
                 '          .where((r) => !hidden.contains(r[\'id\']?.toString()))\n'
                 '          .toList();')
    conv_old = 'final rows = await _repo.fetchConversation(me, other);'
    conv_new = ('final hidden = await _repo.fetchHiddenMessageIds(me);\n'
                '      final rows = (await _repo.fetchConversation(me, other))\n'
                '          .where((r) => !hidden.contains(r[\'id\']?.toString()))\n'
                '          .toList();')
    for old in (inbox_old, conv_old):
        if text.count(old) != 1:
            fail(f'expected one match for: {old}')
    text = text.replace(inbox_old, inbox_new).replace(conv_old, conv_new)

    anchor = '  /// Kept for existing callers.'
    if text.count(anchor) != 1:
        fail('anchor not found in chatState.dart')
    method = '''  /// Hide these conversations for the signed-in user. Messages are removed
  /// from the database once both people have hidden them.
  Future<void> deleteConversations(List<String> others) async {
    final me = _myId;
    if (me == null || others.isEmpty) return;
    final ids = others.toSet();
    _chatUserList?.removeWhere((x) => ids.contains(x.key));
    if (_chatUser?.userId != null && ids.contains(_chatUser!.userId)) {
      _messageList = null;
    }
    notifyListeners();
    try {
      for (final other in ids) {
        await _repo.deleteConversation(other);
      }
    } catch (error) {
      await getUserChatList(me);
      rethrow;
    }
    await getUserChatList(me);
  }

'''
    text = text.replace(anchor, method + anchor)
    STATE.write_text(text, encoding='utf-8')
    print('  chatState: hidden messages filtered, deleteConversations added.')


def patch_screen():
    text = SCREEN.read_text(encoding='utf-8')
    if 'ConversationIntro(' in text:
        print('  chat screen already shows the profile intro.')
        return
    text = add_import(text, "import 'package:flutter_twitter_clone/ui/page/message/widgets/conversation_intro.dart';")
    old = """    if (state.messageList == null || state.messageList!.isEmpty) {
      return const Center(
        child: Text(
          'No message found',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
    }
"""
    new = """    final list = state.messageList;
    if (list == null) return const SizedBox.shrink();
    if (list.isEmpty) return ConversationIntro(user: state.chatUser!);
"""
    if text.count(old) != 1:
        fail('empty-chat block not found in chatScreenPage.dart')
    SCREEN.write_text(text.replace(old, new), encoding='utf-8')
    print('  chat screen: empty conversation shows the profile intro.')


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not LIB.exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    for path in REQUIRED_NEW:
        if not path.exists():
            fail(f'{path} is missing. Unzip the whole archive first.')
    print('1/2 Chat state (delete + hidden filter)')
    patch_state()
    print('2/2 Empty conversation profile')
    patch_screen()
    print('Done. Run the SQL migration in Supabase SQL Editor next.')


if __name__ == '__main__':
    main()
