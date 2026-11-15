// lib/ui/page/message/widgets/conversation_intro.dart
//
// Shown in the middle of a conversation that has no messages yet: avatar,
// display name with verified badge, username, and follower/following counts.
import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/supabase/supabase_chat_delete.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/profile/profilePage.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/title_text.dart';
import 'package:flutter_twitter_clone/widgets/verified_badge.dart';

class ConversationIntro extends StatefulWidget {
  const ConversationIntro({super.key, required this.user});

  final UserModel user;

  @override
  State<ConversationIntro> createState() => _ConversationIntroState();
}

class _ConversationIntroState extends State<ConversationIntro> {
  ProfileSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConversationIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.userId != widget.user.userId) {
      _summary = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.user.userId;
    if (id == null) return;
    try {
      final summary =
          await SupabaseRepository.instance.fetchProfileSummary(id);
      if (!mounted || widget.user.userId != id) return;
      setState(() => _summary = summary);
    } catch (error) {
      debugPrint('ConversationIntro load failed: $error');
    }
  }

  Widget _stat(int? value, String label) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value == null ? '– ' : '$value ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(fontSize: 15, color: AppColor.darkGrey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final verified = _summary?.isVerified ?? user.isVerified ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: user.userId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        ProfilePage.getRoute(profileId: user.userId!),
                      ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: CircularImage(
                  path: user.profilePic ?? Constants.dummyProfilePic,
                  height: 110,
                  isBorder: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TitleText(
                    user.displayName ?? 'NA',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 18),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.userName ?? '',
              textAlign: TextAlign.center,
              style: TextStyles.userNameStyle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat(_summary?.followers, 'Followers'),
                const SizedBox(width: 24),
                _stat(_summary?.following, 'Following'),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'No messages yet. Say hi!',
              style: TextStyle(fontSize: 14, color: AppColor.darkGrey),
            ),
          ],
        ),
      ),
    );
  }
}
