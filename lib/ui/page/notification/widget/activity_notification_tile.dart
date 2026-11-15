import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/model/notificationModel.dart';
import 'package:flutter_twitter_clone/ui/page/profile/profilePage.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// Fallback tile for activity events that do not point to a post or list.
class ActivityNotificationTile extends StatelessWidget {
  const ActivityNotificationTile({super.key, required this.model});

  final NotificationModel model;

  String _action(String kind) {
    switch (kind) {
      case 'follow_request':
        return 'requested to follow you';
      case 'follow_accept':
        return 'accepted your follow request';
      case 'story_reaction':
      case 'reaction':
        return 'reacted to your story';
      case 'story_reply':
        return 'replied to your story';
      case 'profile_visit':
        return 'visited your profile';
      default:
        return 'sent you an update';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = model.data ?? <String, dynamic>{};
    final name = (data['displayName'] ?? 'Someone').toString();
    final kind = (data['kind'] ?? '').toString();
    final preview = (data['preview'] ?? '').toString();
    final emoji = (data['emoji'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();
    final imageUrl = (data['profilePic'] ?? '').toString();
    final hasImage = imageUrl.startsWith('http');

    return Column(
      children: [
        InkWell(
          onTap: userId.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    ProfilePage.getRoute(profileId: userId),
                  ),
          child: Container(
            color: TwitterColor.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColor.extraLightGrey,
                  foregroundImage: hasImage ? NetworkImage(imageUrl) : null,
                  child: hasImage
                      ? null
                      : Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' ${_action(kind)}'),
                          ],
                        ),
                      ),
                      if (preview.isNotEmpty || emoji.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [emoji, preview].where((value) => value.isNotEmpty).join(' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 0, thickness: .6),
      ],
    );
  }
}


