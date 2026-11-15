import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// Bold black title text, Mulish like the rest of the app.
TextStyle listTitleStyle({double size = 16, Color color = Colors.black}) {
  return GoogleFonts.mulish(
      fontSize: size, fontWeight: FontWeight.w800, color: color);
}

/// Grey secondary text, the same grey the app uses for subtitles.
TextStyle listGreyStyle({double size = 13, FontWeight weight = FontWeight.w700}) {
  return GoogleFonts.mulish(
      fontSize: size, fontWeight: weight, color: AppColor.darkGrey);
}

String compactCount(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  }
  return '$n';
}

/// A list's square cover: its photo, or its gradient with the list icon.
class ListCover extends StatelessWidget {
  const ListCover({super.key, required this.list, this.size = 56, this.radius = 12});

  final SwiflyList list;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cover = list.coverUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: cover == null
            ? LinearGradient(
                colors: list.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        image: cover == null
            ? null
            : DecorationImage(
                image: customAdvanceNetworkImage(cover),
                fit: BoxFit.cover,
              ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: cover == null
          ? Center(
              child: Icon(list.iconData,
                  color: Colors.white, size: size * 0.46),
            )
          : null,
    );
  }
}

/// A tappable list attachment shown directly inside a post.
/// Its cover, list name and counts are visible without opening the list first.
class ListPostAttachment extends StatelessWidget {
  const ListPostAttachment({
    super.key,
    required this.list,
    required this.onTap,
  });

  final SwiflyList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: radius,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListCover(list: list, size: 64, radius: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        list.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: listTitleStyle(size: 14),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${compactCount(list.memberCount)} members · '
                        '${compactCount(list.followerCount)} followers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: listGreyStyle(size: 12, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            list.isPrivate ? Icons.lock_outline : Icons.public,
                            size: 13,
                            color: AppColor.darkGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            list.isPrivate ? 'Private list' : 'Public list',
                            style: listGreyStyle(size: 11, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: AppColor.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round profile photo with the app's placeholder when there is none.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, this.url, this.radius = 18});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = (url == null || url!.isEmpty) ? Constants.dummyProfilePic : url;
    return CircleAvatar(
      radius: radius,
      backgroundColor: TwitterColor.mystic,
      backgroundImage: customAdvanceNetworkImage(photo),
    );
  }
}

/// "Public" or "Private" with a small icon.
class ListPrivacyTag extends StatelessWidget {
  const ListPrivacyTag({super.key, required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isPrivate ? Icons.lock_outline : Icons.public,
            size: 14, color: AppColor.darkGrey),
        const SizedBox(width: 4),
        Text(isPrivate ? 'Private' : 'Public', style: listGreyStyle(size: 12)),
      ],
    );
  }
}

/// Blue "Follow" pill that turns white with a blue border to show "Following".
class ListFollowButton extends StatelessWidget {
  const ListFollowButton({
    super.key,
    required this.following,
    required this.onTap,
  });

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: following ? Colors.white : AppColor.primary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColor.primary, width: 1.5),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: listTitleStyle(
              size: 14, color: following ? AppColor.primary : Colors.white),
        ),
      ),
    );
  }
}

/// Divider colour used throughout the app.
const Color kListDividerColor = Color(0xffEFF3F4);

/// Compact empty state for the Lists screens (the shared EmptyList is full-screen).
class ListEmptyState extends StatelessWidget {
  const ListEmptyState(this.title, {super.key, required this.subTitle});

  final String title;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt, size: 40, color: AppColor.lightGrey),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: listTitleStyle(size: 16)),
          const SizedBox(height: 6),
          Text(
            subTitle,
            textAlign: TextAlign.center,
            style: listGreyStyle(size: 14, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}


