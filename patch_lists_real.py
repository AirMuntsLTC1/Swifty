#!/usr/bin/env python3
"""Wires the Lists feature into the app. Run from the project root (the folder
that contains lib/). Every edit checks its anchor text first and stops without
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


# 1. The old mock data file from the previous version is no longer used.
mock = 'lib/mock/lists_mock.dart'
if os.path.exists(mock):
    os.remove(mock)
    print('Removed old mock file', mock)

# 2. New notification type.
path = 'lib/helper/enum.dart'
text = read(path)
if 'ListAdd' in text:
    print('NotificationType.ListAdd already present')
else:
    start = text.index('enum NotificationType {')
    end = text.index('}', start)
    block = replace_once(text[start:end], '  Like\n', '  Like,\n  ListAdd\n', 'enum')
    write(path, text[:start] + block + text[end:])
    print('Added NotificationType.ListAdd')

# 3. Notification state: read list_add rows and group them.
path = 'lib/state/notificationState.dart'
text = read(path)
if "'list_add'" in text:
    print('notificationState already handles list_add')
else:
    text = replace_once(
        text,
        "      if (!isFollow && postId == null) continue;\n",
        "      final isList = type == NotificationType.ListAdd.toString();\n"
        "      final listId = row['list_id']?.toString();\n"
        "      if (isList && listId == null) continue;\n"
        "      if (!isFollow && !isList && postId == null) continue;\n",
        'state-skip',
    )
    text = replace_once(
        text,
        "      final groupKey = isFollow ? 'follow:$actorId' : 'post:$postId:$type';\n",
        "      final groupKey = isFollow\n"
        "          ? 'follow:$actorId'\n"
        "          : isList\n"
        "              ? 'list:$listId:$actorId'\n"
        "              : 'post:$postId:$type';\n",
        'state-group',
    )
    text = replace_once(
        text,
        "          : <String, dynamic>{};\n\n      result.add(NotificationModel(\n",
        "          : isList\n"
        "              ? <String, dynamic>{\n"
        "                  'listId': listId,\n"
        "                  'listName': (row['preview'] ?? '').toString(),\n"
        "                  'userId': actorId,\n"
        "                  'displayName': (row['actor_name'] ?? '').toString(),\n"
        "                  'profilePic': (row['avatar_url'] ?? '').toString().isNotEmpty\n"
        "                      ? row['avatar_url'].toString()\n"
        "                      : Constants.dummyProfilePic,\n"
        "                }\n"
        "              : <String, dynamic>{};\n\n"
        "      result.add(NotificationModel(\n",
        'state-data',
    )
    text = replace_once(
        text,
        "      case 'retweet':\n        return NotificationType.Retweet.toString();\n",
        "      case 'retweet':\n        return NotificationType.Retweet.toString();\n"
        "      case 'list_add':\n        return NotificationType.ListAdd.toString();\n",
        'state-type',
    )
    write(path, text)
    print('Updated notificationState.dart')

# 4. Notification page: show list_add rows with their own tile.
path = 'lib/ui/page/notification/notificationPage.dart'
text = read(path)
if 'ListAddNotificationTile' in text:
    print('notificationPage already shows list_add rows')
else:
    text = replace_once(
        text,
        "import 'package:flutter_twitter_clone/ui/page/notification/widget/follow_notification_tile.dart';\n",
        "import 'package:flutter_twitter_clone/ui/page/notification/widget/follow_notification_tile.dart';\n"
        "import 'package:flutter_twitter_clone/ui/page/notification/widget/list_add_notification_tile.dart';\n",
        'page-import',
    )
    text = replace_once(
        text,
        "  Widget _notificationRow(BuildContext context, NotificationModel model) {\n"
        "    var state = Provider.of<NotificationState>(context);\n",
        "  Widget _notificationRow(BuildContext context, NotificationModel model) {\n"
        "    var state = Provider.of<NotificationState>(context);\n"
        "    if (model.type == NotificationType.ListAdd.toString()) {\n"
        "      return ListAddNotificationTile(model: model);\n"
        "    }\n",
        'page-row',
    )
    write(path, text)
    print('Updated notificationPage.dart')

# 5. Side menu: turn on the Lists item and open ListsPage.
path = 'lib/ui/page/common/sidebar.dart'
text = read(path)
if 'ListsPage.getRoute' in text:
    print('Side menu already opens ListsPage')
else:
    text = replace_once(
        text,
        "import 'package:flutter_twitter_clone/ui/page/bookmark/bookmarkPage.dart';\n",
        "import 'package:flutter_twitter_clone/ui/page/bookmark/bookmarkPage.dart';\n"
        "import 'package:flutter_twitter_clone/ui/page/lists/listsPage.dart';\n",
        'sidebar-import',
    )
    text = replace_once(
        text,
        "_menuListRowButton('Lists', icon: AppIcon.lists),",
        "_menuListRowButton('Lists', icon: AppIcon.lists, isEnable: true,\n"
        "                      onPressed: () {\n"
        "                    Navigator.push(context, ListsPage.getRoute());\n"
        "                  }),",
        'sidebar-row',
    )
    write(path, text)
    print('Side menu: Lists item opens ListsPage')

print('Done. Next: run the SQL migration in Supabase, then build the app.')
