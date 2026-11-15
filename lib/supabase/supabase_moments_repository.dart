// lib/supabase/supabase_moments_repository.dart
//
// Data layer for Moments: 24-hour stories, reactions, replies, capsules and
// the explore grid. Reads rely on RLS. Stories are visible only to the author
// and the people they follow (swifs_stories_read). Posts follow the normal
// audience rules.
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/video_thumbnail_helper.dart';
import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/moment_models.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

const String _postSelect =
    'id, author_id, text, audience, tagged_handles, likes, saves, shares, created_at, views, list_id';

class MomentsRepository {
  MomentsRepository._();
  static final MomentsRepository instance = MomentsRepository._();

  final SupabaseRepository _base = SupabaseRepository.instance;

  SupabaseClient get db => _base.db;
  String? get uid => _base.uid;

  /// Shows a failure to the user, then rethrows for the caller to handle.
  Future<T> _run<T>(String where, Future<T> Function() op) async {
    try {
      return await op();
    } catch (error) {
      showAppError(error, where: where);
      rethrow;
    }
  }

  String _storyUrl(String stored) {
    if (stored.startsWith('http')) return stored;
    return db.storage.from(kStoriesBucket).getPublicUrl(stored);
  }

  // ---------------------------------------------------------------------------
  // Story ring
  // ---------------------------------------------------------------------------

  /// Your own Moments first, then people you follow with a live story.
  /// Unseen rings are ordered before seen ones.
  Future<List<MomentRing>> fetchRings() {
    return _run('Load Moments', () async {
      final me = uid;
      if (me == null) return <MomentRing>[];

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final storyRows = List<Map<String, dynamic>>.from(
        await db
            .from('stories')
            .select()
            .gt('expires_at', nowIso)
            .order('created_at', ascending: false)
            .limit(300),
      );
      if (storyRows.isEmpty) return <MomentRing>[];

      final storyIds = storyRows.map((r) => r['id'].toString()).toList();
      final authorIds =
          storyRows.map((r) => r['author_id'].toString()).toSet().toList();

      final results = await Future.wait<dynamic>([
        db
            .from('profiles')
            .select('id, username, display_name, avatar_url')
            .inFilter('id', authorIds),
        db
            .from('story_views')
            .select('story_id')
            .eq('viewer_id', me)
            .inFilter('story_id', storyIds),
      ]);

      final authors = <String, MomentAuthor>{
        for (final row in results[0] as List)
          row['id'].toString():
              MomentAuthor.fromRow(Map<String, dynamic>.from(row as Map)),
      };
      final seen = (results[1] as List)
          .map((r) => r['story_id'].toString())
          .toSet();

      final byAuthor = <String, List<MomentStory>>{};
      for (final row in storyRows) {
        final story = MomentStory.fromRow(row, _storyUrl);
        byAuthor.putIfAbsent(story.authorId, () => []).add(story);
      }

      final rings = byAuthor.entries.map((entry) {
        // Rows arrive newest first. Reverse so the viewer plays oldest first.
        final stories = entry.value.reversed.toList();
        return MomentRing(
          author: authors[entry.key] ?? MomentAuthor.unknown(entry.key),
          stories: stories,
          hasUnseen: stories.any((s) => !seen.contains(s.id)),
          isMine: entry.key == me,
        );
      }).toList();

      rings.sort((a, b) {
        if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
        if (a.hasUnseen != b.hasUnseen) return a.hasUnseen ? -1 : 1;
        return b.latest.compareTo(a.latest);
      });
      return rings;
    });
  }

  /// Posting a story. Either a photo (uploaded to the stories bucket) or text
  /// on a colored background. Expires 24 hours after posting.
  Future<String> createStory({
    File? image,
    File? video,
    String? text,
    int? bgColor,
    String? place,
  }) {
    return _run('Post Moment', () async {
      final me = uid;
      if (me == null) throw StateError('Not signed in');

      final caption = text?.trim() ?? '';
      final hasText = caption.isNotEmpty;
      if (image == null && video == null && !hasText) {
        throw StateError('Add a photo, a video or some text first');
      }

      // A story holds one piece of media. A video takes priority.
      String? photoUrl;
      String? thumbUrl;
      String mediaType = 'text';
      if (video != null) {
        photoUrl = await _base.uploadFile(kStoriesBucket, video);
        mediaType = 'video';
        // The thumbnail is best effort: the story still posts without it.
        final thumb = await makeVideoThumbnail(video);
        if (thumb != null) {
          try {
            thumbUrl = await _base.uploadFile(kStoriesBucket, thumb);
          } catch (_) {
            thumbUrl = null;
          }
        }
      } else if (image != null) {
        photoUrl = await _base.uploadFile(kStoriesBucket, image);
        mediaType = 'image';
      }

      final now = DateTime.now().toUtc();
      final row = await db
          .from('stories')
          .insert({
            'author_id': me,
            'media_type': mediaType,
            'thumbnail_url': thumbUrl,
            'photo_path': photoUrl,
            'bg_color': photoUrl == null ? bgColor : null,
            'layers': [
              if (hasText) {'kind': 'text', 'text': caption},
            ],
            'place': (place == null || place.isEmpty) ? null : place,
            'photo_scale': 1,
            'photo_dx': 0,
            'photo_dy': 0,
            'photo_rotation': 0,
            'created_at': now.toIso8601String(),
            'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
          })
          .select('id')
          .single();
      return row['id'].toString();
    });
  }

  Future<void> deleteStory(String storyId) {
    return _run('Delete Moment', () async {
      await db.from('stories').delete().eq('id', storyId);
    });
  }

  // ---------------------------------------------------------------------------
  // Views, reactions, replies
  // ---------------------------------------------------------------------------

  /// Records that you watched a story. Repeat calls are ignored.
  Future<void> markViewed(String storyId) {
    return _run('Mark viewed', () async {
      final me = uid;
      if (me == null) return;
      await db.from('story_views').upsert(
        {'story_id': storyId, 'viewer_id': me},
        onConflict: 'story_id,viewer_id',
        ignoreDuplicates: true,
      );
    });
  }

  /// One reaction per viewer per story. Tapping another emoji replaces it.
  /// The row is updated, not inserted again, so the notification trigger does
  /// not fire a second time.
  Future<void> react(String storyId, String emoji) {
    return _run('React to story', () async {
      final me = uid;
      if (me == null) return;
      await db.from('story_reactions').upsert(
        {'story_id': storyId, 'user_id': me, 'emoji': emoji},
        onConflict: 'story_id,user_id',
        ignoreDuplicates: false,
      );
    });
  }

  Future<void> reply(String storyId, String text) {
    return _run('Send reply', () async {
      final me = uid;
      final clean = text.trim();
      if (me == null || clean.isEmpty) return;
      await db.from('story_replies').insert({
        'story_id': storyId,
        'user_id': me,
        'text': clean,
      });
    });
  }

  /// Views and reaction counts. Only the author can read these rows (RLS).
  Future<StoryStats> fetchStats(String storyId) {
    return _run('Load story stats', () async {
      final results = await Future.wait<dynamic>([
        db.from('story_views').select('viewer_id').eq('story_id', storyId),
        db.from('story_reactions').select('emoji').eq('story_id', storyId),
      ]);
      final counts = <String, int>{};
      for (final row in results[1] as List) {
        final emoji = row['emoji'].toString();
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
      return StoryStats(
        views: (results[0] as List).length,
        reactions: counts,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Capsules and explore
  // ---------------------------------------------------------------------------

  /// One capsule per trending tag: recent posts that use it, most liked first.
  Future<List<MomentCapsule>> fetchCapsules({
    int tagLimit = 5,
    int postsPerTag = 12,
  }) {
    return _run('Load capsules', () async {
      var tagRows = List<Map<String, dynamic>>.from(
        await db
            .from('trending_tags')
            .select('tag, uses')
            .order('uses', ascending: false)
            .limit(tagLimit),
      );
      // trending_tags is not filled by the app yet. Until it is, derive the
      // trending tags from hashtags used in recent posts.
      if (tagRows.isEmpty) {
        tagRows = await _tagsFromRecentPosts(tagLimit);
      }

      final capsules = await Future.wait<MomentCapsule?>(
        tagRows.map((row) async {
          // Strip anything that could break the LIKE pattern.
          final tag = row['tag']
              .toString()
              .replaceAll('#', '')
              .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
          if (tag.isEmpty) return null;

          final rows = List<Map<String, dynamic>>.from(
            await db
                .from('posts')
                .select(_postSelect)
                .ilike('text', '%#$tag%')
                .order('likes', ascending: false)
                .limit(postsPerTag),
          );
          final posts = await _base.hydratePosts(rows);
          if (posts.isEmpty) return null;

          return MomentCapsule(
            tag: tag,
            uses: (row['uses'] as num?)?.toInt() ?? 0,
            posts: posts,
          );
        }),
      );
      return capsules.whereType<MomentCapsule>().toList();
    });
  }

  /// Hashtags used by at least two of the 200 newest posts, most used first.
  Future<List<Map<String, dynamic>>> _tagsFromRecentPosts(int limit) async {
    final rows = List<Map<String, dynamic>>.from(
      await db
          .from('posts')
          .select('text')
          .order('created_at', ascending: false)
          .limit(200),
    );
    final counts = <String, int>{};
    final pattern = RegExp(r'#([A-Za-z0-9_]{2,30})');
    for (final row in rows) {
      final text = (row['text'] ?? '').toString();
      final seenInPost = <String>{};
      for (final match in pattern.allMatches(text)) {
        final tag = match.group(1)!.toLowerCase();
        if (seenInPost.add(tag)) counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <Map<String, dynamic>>[];
    for (final entry in ranked.take(limit)) {
      result.add({'tag': entry.key, 'uses': entry.value});
    }
    return result;
  }

  /// Explore grid. [trending] sorts by likes, otherwise newest first.
  Future<List<FeedModel>> fetchExplore({
    required bool trending,
    int limit = 60,
  }) {
    return _run('Load Moments', () async {
      final rows = trending
          ? await db
              .from('posts')
              .select(_postSelect)
              .order('likes', ascending: false)
              .order('created_at', ascending: false)
              .limit(limit)
          : await db
              .from('posts')
              .select(_postSelect)
              .order('created_at', ascending: false)
              .limit(limit);
      return _base.hydratePosts(List<Map<String, dynamic>>.from(rows));
    });
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Calls [onChange] whenever any story is added, changed or removed.
  /// RLS applies, so you only hear about stories you are allowed to see.
  RealtimeChannel subscribeStories(String name, void Function() onChange) {
    return db.channel(name)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'stories',
        callback: (_) => onChange(),
      )
      ..subscribe();
  }

  /// Calls [onInsert] for each new reaction on one story (used by the author
  /// to see reactions arrive live).
  RealtimeChannel subscribeReactions(
    String storyId,
    void Function(Map<String, dynamic> row) onInsert,
  ) {
    return db.channel('story-reactions-$storyId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'story_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'story_id',
          value: storyId,
        ),
        callback: (payload) =>
            onInsert(Map<String, dynamic>.from(payload.newRecord)),
      )
      ..subscribe();
  }

  Future<void> closeChannel(RealtimeChannel channel) async {
    await db.removeChannel(channel);
  }
}




