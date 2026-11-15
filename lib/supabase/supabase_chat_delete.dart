// lib/supabase/supabase_chat_delete.dart
//
// Conversation delete and profile summary calls. Kept in its own file so the
// main repository stays unchanged.
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

class ProfileSummary {
  const ProfileSummary({
    required this.followers,
    required this.following,
    required this.isVerified,
  });

  final int followers;
  final int following;
  final bool isVerified;
}

extension SupabaseChatDelete on SupabaseRepository {
  /// Ids of messages the signed-in user has hidden (deleted for themselves).
  Future<Set<String>> fetchHiddenMessageIds(String me) async {
    final rows = await db
        .from('message_hidden')
        .select('message_id')
        .eq('user_id', me);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => row['message_id'].toString())
        .toSet();
  }

  /// Hide the conversation with [otherUserId] for the signed-in user.
  /// The server removes the messages once both people have hidden them.
  Future<void> deleteConversation(String otherUserId) async {
    await db.rpc(
      'swifs_delete_conversation',
      params: {'other_id': otherUserId},
    );
  }

  /// Real follower and following counts (from the follows table) and the
  /// verified flag for a profile.
  Future<ProfileSummary> fetchProfileSummary(String id) async {
    final profile = await db
        .from('profiles')
        .select('is_verified')
        .eq('id', id)
        .maybeSingle();
    final followers =
        await db.from('follows').select('follower').eq('followee', id);
    final following =
        await db.from('follows').select('followee').eq('follower', id);
    return ProfileSummary(
      followers: List.from(followers as List).length,
      following: List.from(following as List).length,
      isVerified: profile?['is_verified'] == true,
    );
  }
}
