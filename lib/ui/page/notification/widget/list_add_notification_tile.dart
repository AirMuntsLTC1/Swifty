import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/model/notificationModel.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/page/lists/listDetailPage.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// "<name> added you to a list". Tapping it opens the list.
class ListAddNotificationTile extends StatelessWidget {
  const ListAddNotificationTile({super.key, required this.model});

  final NotificationModel model;

  @override
  Widget build(BuildContext context) {
    final data = model.data ?? <String, dynamic>{};
    final listId = (data['listId'] ?? '').toString();
    final listName = (data['listName'] ?? 'a list').toString();
    final name = (data['displayName'] ?? 'Someone').toString();
    final picture = data['profilePic']?.toString();

    return Column(
      children: [
        InkWell(
          onTap: listId.isEmpty
              ? null
              : () => Navigator.push(context, ListDetailPage.getRoute(listId)),
          child: Container(
            color: TwitterColor.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                PersonAvatar(url: picture, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: listGreyStyle(size: 14, weight: FontWeight.w600),
                          children: [
                            TextSpan(text: name, style: listTitleStyle(size: 14)),
                            const TextSpan(text: ' added you to a list'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: listTitleStyle(size: 15, color: AppColor.primary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColor.darkGrey),
              ],
            ),
          ),
        ),
        const Divider(height: 0, thickness: .6),
      ],
    );
  }
}
