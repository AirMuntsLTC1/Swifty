// lib/supabase/supabase_story_engagement.dart
//
// Likes, reposts and comment counts for Moments (stories).
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

class StoryEngagement {
  const StoryEngagement({
    required this.likes,
    required this.liked,
    required this.reposts,
    required this.reposted,
    required this.comments,
  });

  final int likes;
  final bool liked;
  final int reposts;
  final bool reposted;
  final int comments;

  StoryEngagement copyWith({int? likes, bool? liked, int? reposts, bool? reposted}) {
    return StoryEngagement(
      likes: likes ?? this.likes,
      liked: liked ?? this.liked,
      reposts: reposts ?? this.reposts,
      reposted: reposted ?? this.reposted,
      comments: comments,
    );
  }
}

class StoryEngagementRepository {
  StoryEngagementRepository._();

  static SupabaseRepository get _repo => SupabaseRepository.instance;

  static Future<StoryEngagement> fetch(String storyId) async {
    final db = _repo.db;
    final me = _repo.uid;
    final likeRows = List<Map<String, dynamic>>.from(
      await db.from('story_likes').select('user_id').eq('story_id', storyId) as List,
    );
    final repostRows = List<Map<String, dynamic>>.from(
      await db.from('story_reposts').select('user_id').eq('story_id', storyId) as List,
    );
    var comments = 0;
    try {
      final replies =
          await db.from('story_replies').select('id').eq('story_id', storyId) as List;
      comments = replies.length;
    } catch (_) {
      // Comment count is optional. Show 0 if the table cannot be read.
    }
    return StoryEngagement(
      likes: likeRows.length,
      liked: likeRows.any((row) => row['user_id'] == me),
      reposts: repostRows.length,
      reposted: repostRows.any((row) => row['user_id'] == me),
      comments: comments,
    );
  }

  static Future<void> setLike(String storyId, bool on) =>
      _toggle('story_likes', storyId, on);

  static Future<void> setRepost(String storyId, bool on) =>
      _toggle('story_reposts', storyId, on);

  static Future<void> _toggle(String table, String storyId, bool on) async {
    final db = _repo.db;
    final me = _repo.uid;
    if (me == null) throw StateError('Not signed in');
    if (on) {
      await db
          .from(table)
          .upsert({'story_id': storyId, 'user_id': me}, onConflict: 'story_id,user_id');
    } else {
      await db.from(table).delete().eq('story_id', storyId).eq('user_id', me);
    }
  }
}
