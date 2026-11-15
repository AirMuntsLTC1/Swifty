#!/usr/bin/env python3
"""Adds list joining, join requests, posting to lists, list notifications, and
red badges. Run from the project root (the folder that contains lib/) AFTER
patch_lists_real.py. Each edit checks its anchor first and stops without
changing anything if the anchor is not found exactly once. Safe to run again."""
import os
import sys


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit(f'[{label}] expected the anchor once, found {count}. '
                 'Nothing was changed. Send this message to Claude.')
    return text.replace(old, new, 1)


def edit(path, steps):
    if not os.path.exists(path):
        sys.exit(f'{path} not found. Run this from the project root.')
    text = read(path)
    for label, old, new in steps:
        text = replace_once(text, old, new, label)
    write(path, text)
    print('Updated', path)


# 1. Notification type for all list activity.
path = 'lib/helper/enum.dart'
text = read(path)
if 'ListActivity' in text:
    print('enum already has ListActivity')
else:
    edit(path, [('enum', '  ListAdd\n}', '  ListAdd,\n  ListActivity\n}')])

# 2. Notification state: map every list kind to ListActivity and keep the kind.
path = 'lib/state/notificationState.dart'
if "'list_join'" in read(path):
    print('notificationState already handles list kinds')
else:
    edit(path, [
        ('state-isList',
         '      final isList = type == NotificationType.ListAdd.toString();\n',
         '      final isList = type == NotificationType.ListActivity.toString();\n'),
        ('state-cases',
         "      case 'list_add':\n        return NotificationType.ListAdd.toString();\n",
         "      case 'list_add':\n"
         "      case 'list_join':\n"
         "      case 'list_request':\n"
         "      case 'list_request_accepted':\n"
         "      case 'list_post':\n"
         "        return NotificationType.ListActivity.toString();\n"),
        ('state-kind',
         "                  'listId': listId,\n",
         "                  'listId': listId,\n"
         "                  'kind': rawType,\n"),
        ('state-groupkey',
         "              ? 'list:$listId:$actorId'\n",
         "              ? 'list:$listId:$actorId:$rawType'\n"),
    ])

# 3. Notification page: list rows use ListActivity, and opening the tab clears the badge.
path = 'lib/ui/page/notification/notificationPage.dart'
text = read(path)
if 'BadgeState' in text:
    print('notificationPage already updated')
else:
    edit(path, [
        ('page-branch',
         '    if (model.type == NotificationType.ListAdd.toString()) {\n',
         '    if (model.type == NotificationType.ListActivity.toString()) {\n'),
        ('page-import',
         "import 'package:flutter_twitter_clone/state/notificationState.dart';\n",
         "import 'package:flutter_twitter_clone/state/notificationState.dart';\n"
         "import 'package:flutter_twitter_clone/state/badgeState.dart';\n"),
        ('page-clear',
         '      state.getDataFromDatabase(authState.userId);\n    });\n',
         '      state.getDataFromDatabase(authState.userId);\n'
         '      Provider.of<BadgeState>(context, listen: false).clearNotifications();\n'
         '    });\n'),
    ])

# 4. Bottom bar: red badge on the notifications (bell) and messages (mail) icons.
path = 'lib/widgets/bottomMenuBar/bottomMenuBar.dart'
text = read(path)
if '_badged(' in text:
    print('bottom bar already has badges')
else:
    edit(path, [
        ('bar-import',
         "import 'package:flutter_twitter_clone/state/appState.dart';\n",
         "import 'package:flutter_twitter_clone/state/appState.dart';\n"
         "import 'package:flutter_twitter_clone/state/badgeState.dart';\n"),
        ('bar-icon',
         '                  ? customIcon(context,\n'
         '                      icon: icon!,\n'
         '                      size: 22,\n'
         '                      isTwitterIcon: false,\n'
         '                      isEnable: index == state.pageIndex)\n',
         '                  ? _badged(index, customIcon(context,\n'
         '                      icon: icon!,\n'
         '                      size: 22,\n'
         '                      isTwitterIcon: false,\n'
         '                      isEnable: index == state.pageIndex))\n'),
        ('bar-method',
         '  Widget _icon(IconData? iconData, int index,\n',
         '  /// Red count badge: index 2 is notifications, index 3 is messages.\n'
         '  Widget _badged(int index, Widget child) {\n'
         '    final badge = Provider.of<BadgeState>(context);\n'
         '    final count = index == 2\n'
         '        ? badge.notifications\n'
         '        : index == 3\n'
         '            ? badge.messages\n'
         '            : 0;\n'
         '    if (count <= 0) return child;\n'
         '    return Stack(\n'
         '      clipBehavior: Clip.none,\n'
         '      alignment: Alignment.center,\n'
         '      children: [\n'
         '        child,\n'
         '        Positioned(\n'
         '          top: -6,\n'
         '          right: -10,\n'
         '          child: Container(\n'
         '            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),\n'
         '            padding: const EdgeInsets.symmetric(horizontal: 5),\n'
         '            alignment: Alignment.center,\n'
         '            decoration: BoxDecoration(\n'
         '              color: TwitterColor.ceriseRed,\n'
         '              borderRadius: BorderRadius.circular(9),\n'
         '              border: Border.all(color: Colors.white, width: 1.5),\n'
         '            ),\n'
         "            child: Text(\n"
         "              count > 99 ? '99+' : '$count',\n"
         '              style: const TextStyle(\n'
         '                color: Colors.white,\n'
         '                fontSize: 10,\n'
         '                fontWeight: FontWeight.w800,\n'
         '              ),\n'
         '            ),\n'
         '          ),\n'
         '        ),\n'
         '      ],\n'
         '    );\n'
         '  }\n\n'
         '  Widget _icon(IconData? iconData, int index,\n'),
    ])

# 5. Provide BadgeState to the whole app.
path = 'lib/main.dart'
text = read(path)
if 'BadgeState' in text:
    print('main.dart already provides BadgeState')
else:
    edit(path, [
        ('main-import',
         "import 'package:flutter_twitter_clone/state/suggestionUserState.dart';\n",
         "import 'package:flutter_twitter_clone/state/suggestionUserState.dart';\n"
         "import 'package:flutter_twitter_clone/state/badgeState.dart';\n"),
        ('main-provider',
         '        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()),\n',
         '        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState()),\n'
         '        ChangeNotifierProvider<BadgeState>(create: (_) => BadgeState()),\n'),
    ])

# 6. Home page: start the badge counts and live updates after sign-in.
path = 'lib/ui/page/homePage.dart'
text = read(path)
if 'BadgeState' in text:
    print('homePage already starts BadgeState')
else:
    edit(path, [
        ('home-import',
         "import 'package:flutter_twitter_clone/state/chats/chatState.dart';\n",
         "import 'package:flutter_twitter_clone/state/chats/chatState.dart';\n"
         "import 'package:flutter_twitter_clone/state/badgeState.dart';\n"),
        ('home-start',
         '    state.databaseInit(authState.userId);\n    state.getDataFromDatabase(authState.userId);\n',
         '    state.databaseInit(authState.userId);\n    state.getDataFromDatabase(authState.userId);\n'
         '    Provider.of<BadgeState>(context, listen: false).start(authState.userId);\n'),
    ])

# 7. Composer: list icon, the chosen list chip, and tagging the new post.
path = 'lib/ui/page/feed/composeTweet/composeTweet.dart'
text = read(path)
if '_openListPicker' in text:
    print('composer already has the list icon')
else:
    edit(path, [
        ('compose-imports',
         "import 'package:flutter_twitter_clone/ui/theme/theme.dart';\n",
         "import 'package:flutter_twitter_clone/ui/theme/theme.dart';\n"
         "import 'package:flutter_twitter_clone/model/swifly_list.dart';\n"
         "import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';\n"
         "import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';\n"
         "import 'package:flutter_twitter_clone/ui/page/lists/list_picker_sheet.dart';\n"),
        ('compose-icon-cb',
         '              onImageIconSelected: _onImageIconSelected,\n',
         '              onImageIconSelected: _onImageIconSelected,\n'
         '              onListIconPressed: _openListPicker,\n'),
        ('compose-chip',
         '          Align(\n            alignment: Alignment.bottomCenter,\n            child: ComposeBottomIconWidget(',
         '          if (_selectedList != null)\n'
         '            Positioned(\n'
         '              left: 16,\n'
         '              bottom: 52,\n'
         '              child: _selectedListChip(),\n'
         '            ),\n'
         '          Align(\n            alignment: Alignment.bottomCenter,\n            child: ComposeBottomIconWidget('),
        ('compose-methods',
         '  void _onImageIconSelected(File file) {\n',
         '  SwiflyList? _selectedList;\n\n'
         '  Future<void> _openListPicker() async {\n'
         '    final picked = await showModalBottomSheet<SwiflyList>(\n'
         '      context: context,\n'
         '      isScrollControlled: true,\n'
         '      backgroundColor: Colors.white,\n'
         '      shape: const RoundedRectangleBorder(\n'
         '        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),\n'
         '      ),\n'
         '      builder: (_) => const ListPickerSheet(),\n'
         '    );\n'
         '    if (picked != null && mounted) {\n'
         '      setState(() => _selectedList = picked);\n'
         '    }\n'
         '  }\n\n'
         '  Widget _selectedListChip() {\n'
         '    final list = _selectedList!;\n'
         '    return InputChip(\n'
         '      avatar: customIcon(context,\n'
         '          icon: AppIcon.lists,\n'
         '          isTwitterIcon: false,\n'
         '          iconColor: AppColor.primary),\n'
         '      label: Text(list.name,\n'
         '          style: listTitleStyle(size: 14, color: AppColor.primary)),\n'
         '      backgroundColor: TwitterColor.mystic,\n'
         '      deleteIconColor: AppColor.primary,\n'
         '      side: BorderSide.none,\n'
         '      onDeleted: () => setState(() => _selectedList = null),\n'
         '    );\n'
         '  }\n\n'
         '  void _onImageIconSelected(File file) {\n'),
        ('compose-tag',
         '      tweetModel.key = tweetId;\n',
         '      tweetModel.key = tweetId;\n\n'
         '      // Posting into a list is optional; a failure here must not block the post.\n'
         '      final pickedList = _selectedList;\n'
         '      if (pickedList != null && widget.isTweet) {\n'
         '        try {\n'
         '          await SwiflyListsRepository.instance\n'
         '              .tagPostToList(tweetId, pickedList.id);\n'
         '        } catch (error) {\n'
         "          debugPrint('tag to list failed: $error');\n"
         '        }\n'
         '      }\n'),
    ])

# 8. The Lists screen: discover uses Join/Request, and the role label shows Member.
path = 'lib/ui/page/lists/listsPage.dart'
text = read(path)
if 'ListJoinButton(' in text:
    print('listsPage already uses ListJoinButton')
else:
    edit(path, [
        ('lists-import',
         "import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';\n",
         "import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';\n"
         "import 'package:flutter_twitter_clone/ui/page/lists/list_join_button.dart';\n"),
        ('lists-discover-btn',
         '            ListFollowButton(\n'
         '              following: list.isFollowing,\n'
         '              onTap: () => _action(\n'
         '                  () => _repo.setFollow(list.id, follow: !list.isFollowing)),\n'
         '            ),\n',
         '            ListJoinButton(list: list, onChanged: _load),\n'),
        ('lists-role',
         "            : 'Following';\n",
         "            : list.isMember\n"
         "                ? 'Member'\n"
         "                : 'Following';\n"),
    ])

# 9. List detail: Join/Leave, join requests with Accept/Decline, private guard.
path = 'lib/ui/page/lists/listDetailPage.dart'
text = read(path)
if '_requestItems' in text:
    print('listDetailPage already has join requests')
else:
    text = replace_once(
        text,
        "import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';\n",
        "import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';\n"
        "import 'package:flutter_twitter_clone/ui/page/lists/list_join_button.dart';\n",
        'detail-import')
    text = replace_once(
        text,
        '  List<FeedModel> _posts = [];\n',
        '  List<FeedModel> _posts = [];\n'
        '  List<ListJoinRequest> _requests = [];\n',
        'detail-field')
    text = replace_once(
        text,
        '        _repo.fetchTimeline(widget.listId),\n      ]);\n',
        '        _repo.fetchTimeline(widget.listId),\n'
        '        _repo.fetchJoinRequests(widget.listId),\n'
        '      ]);\n',
        'detail-load')
    text = replace_once(
        text,
        '        _posts = results[2] as List<FeedModel>;\n',
        '        _posts = results[2] as List<FeedModel>;\n'
        '        _requests = results[3] as List<ListJoinRequest>;\n',
        'detail-set')

    start = text.index('  Widget _actions(SwiflyList list) {\n')
    end = text.index('  Widget _tabs() {\n')
    if not os.path.exists('patch_assets/detail_actions_block.dart'):
        sys.exit('patch_assets/detail_actions_block.dart is missing from the zip.')
    new_block = read('patch_assets/detail_actions_block.dart')
    text = text[:start] + new_block + text[end:]

    text = replace_once(
        text,
        '  List<Widget> _membersSection(SwiflyList list, String? me) {\n',
        '  List<Widget> _membersSection(SwiflyList list, String? me) {\n'
        '    if (list.isPrivate && !list.canEdit && !list.isMember) {\n'
        '      return [_privateNotice()];\n'
        '    }\n',
        'detail-members-guard')
    text = replace_once(
        text,
        '    if (list.isOwner || _editors.isNotEmpty) {\n',
        '    if (list.canEdit) items.addAll(_requestItems(list));\n'
        '    if (list.isOwner || _editors.isNotEmpty) {\n',
        'detail-requests-slot')
    text = replace_once(
        text,
        '  List<Widget> _timelineSection() {\n',
        '  List<Widget> _timelineSection() {\n'
        '    final current = _list;\n'
        '    if (current != null &&\n'
        '        current.isPrivate &&\n'
        '        !current.canEdit &&\n'
        '        !current.isMember) {\n'
        '      return [_privateNotice()];\n'
        '    }\n',
        'detail-timeline-guard')
    write(path, text)
    print('Updated', path)

print('Done. Next: add the push lines to the push-notify function, run the'
      ' migration 20261125000000_swifly_list_social.sql, then build the app.')




