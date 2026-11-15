// lib/supabase/supabase_repository.dart
//
// Single data layer between the Flutter app and the Supabase tables.
// Every Firebase Realtime Database / Firestore / Storage call in the app was
// replaced by a method in this file. The state classes (AuthState, FeedState,
// ...) call these methods and keep their original public API, so the widgets
// do not need to change.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';

const String kPostMediaBucket = 'post-media';
const String kAvatarBucket = 'avatars';
const String kStoriesBucket = 'stories';

/// Content type for uploads. Without it the storage client sends text/plain,
/// so the image is served with the wrong type and fails to display.
String mimeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.heic':
      return 'image/heic';
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    default:
      return 'image/jpeg';
  }
}

const String _postSelect =
    'id, author_id, text, audience, tagged_handles, likes, saves, shares, created_at, views';

class SupabaseRepository {
  SupabaseRepository._();
  static final SupabaseRepository instance = SupabaseRepository._();

  SupabaseClient get db => Supabase.instance.client;
  String? get uid => db.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  UserModel mapProfile(
    Map<String, dynamic> row, {
    List<String> followers = const [],
    List<String> following = const [],
  }) {
    final id = row['id'].toString();
    final handle = (row['username'] ?? '').toString();
    final avatar = (row['avatar_url'] ?? '').toString();
    final bio = row['bio'];
    return UserModel(
      key: id,
      userId: id,
      email: id == uid ? db.auth.currentUser?.email : '',
      displayName: (row['display_name'] ?? handle).toString(),
      userName: handle.startsWith('@') ? handle : '@$handle',
      profilePic: avatar.isNotEmpty ? avatar : Constants.dummyProfilePic,
      bio: bio == null ? 'Edit profile to update bio' : bio.toString(),
      createdAt: row['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      followers: followers.length,
      following: following.length,
      followersList: List<String>.from(followers),
      followingList: List<String>.from(following),
      isVerified: false,
    );
  }

  UserModel fallbackUser(String id) => UserModel(
        key: id,
        userId: id,
        displayName: 'Swifly user',
        userName: '@user',
        profilePic: Constants.dummyProfilePic,
        bio: '',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        followersList: [],
        followingList: [],
        followers: 0,
        following: 0,
      );

  Map<String, UserModel> _profileMap(List rows) => {
        for (final r in rows)
          (r['id'].toString()): mapProfile(Map<String, dynamic>.from(r as Map))
      };

  /// post_media.storage_path holds the full public URL that was uploaded.
  String mediaUrl(String storedValue) {
    if (storedValue.startsWith('http')) return storedValue;
    return db.storage.from(kPostMediaBucket).getPublicUrl(storedValue);
  }

  // ---------------------------------------------------------------------------
  // Profiles & follows
  // ---------------------------------------------------------------------------

  Future<UserModel?> fetchUser(String userId) async {
    final res = await Future.wait<dynamic>([
      db.from('profiles').select().eq('id', userId).maybeSingle(),
      db.from('follows').select('follower').eq('followee', userId),
      db.from('follows').select('followee').eq('follower', userId),
    ]);
    final profile = res[0] as Map<String, dynamic>?;
    if (profile == null) return null;
    final followers =
        (res[1] as List).map((e) => e['follower'].toString()).toList();
    final following =
        (res[2] as List).map((e) => e['followee'].toString()).toList();
    return mapProfile(profile, followers: followers, following: following);
  }

  /// Users for search / suggestions, with follower and following lists filled.
  Future<List<UserModel>> fetchAllUsers({int limit = 100}) async {
    final rows = List<Map<String, dynamic>>.from(
      await db
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(limit),
    );
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'].toString()).toList();

    final follows = await Future.wait<dynamic>([
      db.from('follows').select('follower, followee').inFilter('followee', ids),
      db.from('follows').select('follower, followee').inFilter('follower', ids),
    ]);

    final followersBy = <String, List<String>>{};
    for (final f in (follows[0] as List)) {
      followersBy
          .putIfAbsent(f['followee'].toString(), () => [])
          .add(f['follower'].toString());
    }
    final followingBy = <String, List<String>>{};
    for (final f in (follows[1] as List)) {
      followingBy
          .putIfAbsent(f['follower'].toString(), () => [])
          .add(f['followee'].toString());
    }

    return rows.map((r) {
      final id = r['id'].toString();
      return mapProfile(
        r,
        followers: followersBy[id] ?? const [],
        following: followingBy[id] ?? const [],
      );
    }).toList();
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final me = uid;
    if (me == null) return;
    final values = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    if (values.isEmpty) return;
    await db.from('profiles').update(values).eq('id', me);
  }

  /// Creates the profile row if the signup trigger did not create one.
  Future<void> ensureOwnProfile() async {
    final user = db.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await db
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) return;
      final meta = user.userMetadata ?? {};
      var handle = (meta['username'] ?? user.email?.split('@').first ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
      if (handle.length < 3) handle = 'user${user.id.substring(0, 8)}';
      await db.from('profiles').insert({
        'id': user.id,
        'username': handle,
        'display_name': (meta['display_name'] ?? handle).toString(),
        'bio': 'Edit profile to update bio',
      });
    } catch (_) {
      // Username collisions are handled by the sign-up flow; ignore here.
    }
  }

  Future<void> setFollow(String targetId, {required bool follow}) async {
    final me = uid;
    if (me == null || me == targetId) return;
    if (follow) {
      await db.from('follows').upsert(
        {'follower': me, 'followee': targetId},
        onConflict: 'follower,followee',
        ignoreDuplicates: true,
      );
    } else {
      await db
          .from('follows')
          .delete()
          .eq('follower', me)
          .eq('followee', targetId);
    }
  }

  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------

  /// Uploads [file] to [bucket] under the user's own folder and returns the
  /// public URL. Storage RLS (see the migration) only allows writes to the
  /// signed-in user's folder.
  Future<String> uploadFile(String bucket, File file) async {
    final me = uid ?? 'anon';
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final path = '$me/${DateTime.now().millisecondsSinceEpoch}$ext';
    await db.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: mimeForExtension(ext),
            upsert: false,
          ),
        );
    return db.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteStorageUrl(String bucket, String url) async {
    final marker = '/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index < 0) return;
    final path = Uri.decodeFull(url.substring(index + marker.length)
        .split('?')
        .first);
    await db.storage.from(bucket).remove([path]);
  }

  // ---------------------------------------------------------------------------
  // Posts, likes, saves
  // ---------------------------------------------------------------------------

  Future<List<FeedModel>> fetchPosts({
    String? authorId,
    List<String>? postIds,
    int limit = 60,
  }) async {
    if (postIds != null && postIds.isEmpty) return [];
    var query = db.from('posts').select(_postSelect);
    if (authorId != null) query = query.eq('author_id', authorId);
    if (postIds != null) query = query.inFilter('id', postIds);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return hydratePosts(List<Map<String, dynamic>>.from(rows));
  }

  Future<FeedModel?> fetchPost(String postId) async {
    final rows = await db.from('posts').select(_postSelect).eq('id', postId).limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return null;
    final posts = await hydratePosts(list);
    return posts.isEmpty ? null : posts.first;
  }

  /// Builds FeedModels (author, media, likes, comment count) for post rows.
  Future<List<FeedModel>> hydratePosts(List<Map<String, dynamic>> posts) async {
    if (posts.isEmpty) return [];
    final ids = posts.map((e) => e['id'].toString()).toList();
    final authorIds =
        posts.map((e) => e['author_id'].toString()).toSet().toList();

    final results = await Future.wait<dynamic>([
      db.from('profiles').select().inFilter('id', authorIds),
      db.from('post_media').select().inFilter('post_id', ids).order('position'),
      db.from('post_likes').select('post_id, user_id').inFilter('post_id', ids),
      db.from('comments').select('id, post_id').inFilter('post_id', ids),
    ]);

    final profiles = _profileMap(results[0] as List);

    final media = <String, String>{};
    for (final m in (results[1] as List)) {
      media.putIfAbsent(
        m['post_id'].toString(),
        () => mediaUrl(m['storage_path'].toString()),
      );
    }

    final likes = <String, List<String>>{};
    for (final l in (results[2] as List)) {
      likes
          .putIfAbsent(l['post_id'].toString(), () => [])
          .add(l['user_id'].toString());
    }

    final comments = <String, List<String>>{};
    for (final c in (results[3] as List)) {
      comments
          .putIfAbsent(c['post_id'].toString(), () => [])
          .add(c['id'].toString());
    }

    return posts.map((row) {
      final id = row['id'].toString();
      final authorId = row['author_id'].toString();
      final likeList = likes[id] ?? <String>[];
      final commentIds = comments[id] ?? <String>[];
      return FeedModel(
        key: id,
        description: row['text'] as String?,
        userId: authorId,
        likeCount: likeList.length,
        likeList: likeList,
        commentCount: commentIds.length,
        replyTweetKeyList: List<String?>.from(commentIds),
        retweetCount: (row['shares'] as num?)?.toInt() ?? 0,
        createdAt: row['created_at'].toString(),
        imagePath: media[id],
        tags: List<String>.from((row['tagged_handles'] as List?) ?? const []),
        user: profiles[authorId] ?? fallbackUser(authorId),
      );
    }).toList();
  }

  Future<String> createPost({
    required String text,
    List<String> tags = const [],
    String? imageUrl,
    String audience = 'everyone',
  }) async {
    final me = uid;
    if (me == null) throw StateError('Not signed in');
    final row = await db
        .from('posts')
        .insert({
          'author_id': me,
          'text': text,
          'audience': audience,
          'tagged_handles': tags,
        })
        .select('id')
        .single();
    final postId = row['id'].toString();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await db.from('post_media').insert({
        'post_id': postId,
        'position': 0,
        'kind': 'image',
        'storage_path': imageUrl,
      });
    }
    return postId;
  }

  Future<void> updatePostText(String postId, String text) async {
    await db.from('posts').update({'text': text}).eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    await db.from('posts').delete().eq('id', postId);
  }

  Future<void> setLike(String postId, {required bool liked}) async {
    final me = uid;
    if (me == null) return;
    if (liked) {
      await db.from('post_likes').upsert(
        {'user_id': me, 'post_id': postId},
        onConflict: 'user_id,post_id',
        ignoreDuplicates: true,
      );
    } else {
      await db
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', me);
    }
  }

  Future<void> setSave(String postId, {required bool saved}) async {
    final me = uid;
    if (me == null) return;
    if (saved) {
      await db.from('post_saves').upsert(
        {'user_id': me, 'post_id': postId},
        onConflict: 'user_id,post_id',
        ignoreDuplicates: true,
      );
    } else {
      await db
          .from('post_saves')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', me);
    }
  }

  Future<List<String>> fetchSavedPostIds() async {
    final me = uid;
    if (me == null) return [];
    final rows = await db
        .from('post_saves')
        .select('post_id')
        .eq('user_id', me)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => r['post_id'].toString()).toList();
  }

  // ---------------------------------------------------------------------------
  // Comments (replies)
  // ---------------------------------------------------------------------------

  /// Newest first. Each FeedModel has `parentkey` = post id.
  Future<List<FeedModel>> fetchComments(String postId) async {
    final rows = List<Map<String, dynamic>>.from(
      await db
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false),
    );
    if (rows.isEmpty) return [];
    final authorIds =
        rows.map((r) => r['author_id'].toString()).toSet().toList();
    final profiles = _profileMap(
      await db.from('profiles').select().inFilter('id', authorIds) as List,
    );
    return rows.map((r) {
      final authorId = r['author_id'].toString();
      return FeedModel(
        key: r['id'].toString(),
        parentkey: postId,
        description: r['text'] as String?,
        userId: authorId,
        likeCount: 0,
        likeList: [],
        commentCount: 0,
        replyTweetKeyList: [],
        retweetCount: 0,
        createdAt: r['created_at'].toString(),
        imagePath: (r['image_url'] == null || r['image_url'].toString().isEmpty)
            ? null
            : r['image_url'].toString(),
        user: profiles[authorId] ?? fallbackUser(authorId),
      );
    }).toList();
  }

  Future<String> addComment({
    required String postId,
    required String text,
    String? parentId,
    String? imageUrl,
  }) async {
    final me = uid;
    if (me == null) throw StateError('Not signed in');
    final row = await db
        .from('comments')
        .insert({
          'post_id': postId,
          'author_id': me,
          'text': text,
          if (parentId != null) 'parent_id': parentId,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> deleteComment(String commentId) async {
    await db.from('comments').delete().eq('id', commentId);
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchNotifications(
    String userId, {
    int limit = 100,
  }) async {
    final rows = await db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markNotificationsRead(String userId) async {
    await db
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  Future<void> deleteNotificationsForPost(String userId, String postId) async {
    await db
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  /// Mentions are not created by a trigger, so the client writes them.
  Future<void> insertMentionNotification({
    required String userId,
    required String postId,
    String? preview,
  }) async {
    final me = uid;
    if (me == null || me == userId) return;
    final profile = await fetchUser(me);
    await db.from('notifications').insert({
      'user_id': userId,
      'type': 'mention',
      'actor_id': me,
      'actor_handle': (profile?.userName ?? '').replaceFirst('@', ''),
      'actor_name': profile?.displayName ?? '',
      'avatar_url': profile?.profilePic,
      'post_id': postId,
      'preview': preview,
    });
  }

  // ---------------------------------------------------------------------------
  // Direct messages
  // ---------------------------------------------------------------------------

  /// All messages in one conversation, newest first.
  Future<List<Map<String, dynamic>>> fetchConversation(
    String me,
    String other,
  ) async {
    final rows = await db
        .from('messages')
        .select()
        .or('and(sender.eq.$me,recipient.eq.$other),and(sender.eq.$other,recipient.eq.$me)')
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Every message involving [me], newest first (used to build the inbox).
  Future<List<Map<String, dynamic>>> fetchInboxRows(String me) async {
    final rows = await db
        .from('messages')
        .select()
        .or('sender.eq.$me,recipient.eq.$me')
        .order('created_at', ascending: false)
        .limit(1000);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String recipient,
    required String text,
  }) async {
    final me = uid;
    if (me == null) throw StateError('Not signed in');
    final row = await db
        .from('messages')
        .insert({'sender': me, 'recipient': recipient, 'text': text})
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> markConversationRead(String me, String other) async {
    await db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('sender', other)
        .eq('recipient', me)
        .isFilter('read_at', null);
  }

  // ---------------------------------------------------------------------------
  // Push tokens (FCM token is stored through a SECURITY DEFINER function)
  // ---------------------------------------------------------------------------

  Future<void> registerPushToken(String token, String platform) async {
    if (uid == null) return;
    try {
      await db.rpc('swifly_register_push_token', params: {
        'p_token': token,
        'p_platform': platform,
      });
    } catch (_) {
      // Push is optional; the app keeps working without it.
    }
  }
}


