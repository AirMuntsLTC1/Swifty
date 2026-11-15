// Data layer for Lists. Reads go straight to the lists tables (RLS decides
// what each user can see). Writes call the swifly_* functions, which check
// the rules and then change the rows.
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/app_error.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// A profile as the Lists screens need it.
class ListPerson {
  const ListPerson({
    required this.id,
    required this.handle,
    required this.name,
    this.avatar,
  });

  final String id;
  final String handle;
  final String name;
  final String? avatar;

  factory ListPerson.fromRow(Map<String, dynamic> row) {
    final username = (row['username'] ?? '').toString();
    final avatar = (row['avatar_url'] ?? '').toString();
    return ListPerson(
      id: row['id'].toString(),
      handle: username.startsWith('@') ? username : '@$username',
      name: (row['display_name'] ?? username).toString(),
      avatar: avatar.isEmpty ? null : avatar,
    );
  }
}

class ListsOverview {
  const ListsOverview({
    required this.pinned,
    required this.discover,
    required this.yours,
  });

  static const ListsOverview empty =
      ListsOverview(pinned: [], discover: [], yours: []);

  final List<SwiflyList> pinned;
  final List<SwiflyList> discover;
  final List<SwiflyList> yours;
}

class SwiflyListsRepository {
  SwiflyListsRepository._();
  static final SwiflyListsRepository instance = SwiflyListsRepository._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _me => _db.auth.currentUser?.id;

  static const String _listColumns =
      'id, owner_id, name, description, icon, cover_url, is_private, '
      'member_count, follower_count, created_at';

  static const String _postColumns =
      'id, author_id, text, audience, tagged_handles, likes, saves, shares, '
      'created_at, views';

  /// Every call goes through here, so a failure is shown with the action name.
  Future<T> _run<T>(String where, Future<T> Function() op) async {
    try {
      return await op();
    } catch (error) {
      showAppError(error, where: where);
      rethrow;
    }
  }

  Future<Map<String, ListPerson>> _people(Iterable<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return <String, ListPerson>{};
    final rows = List<Map<String, dynamic>>.from(
      await _db
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', unique),
    );
    return {
      for (final row in rows) row['id'].toString(): ListPerson.fromRow(row),
    };
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Everything the Lists screen shows: pinned, discover, and your lists.
  Future<ListsOverview> fetchOverview() => _run('Load lists', () async {
        final me = _me;
        if (me == null) return ListsOverview.empty;

        final first = await Future.wait<dynamic>([
          _db
              .from('list_pins')
              .select('list_id')
              .eq('user_id', me)
              .order('position', ascending: true),
          _db.from('list_follows').select('list_id').eq('user_id', me),
          _db.from('list_editors').select('list_id').eq('user_id', me),
          _db
              .from('lists')
              .select(_listColumns)
              .eq('owner_id', me)
              .order('created_at', ascending: false),
          _db
              .from('lists')
              .select(_listColumns)
              .neq('owner_id', me)
              .eq('is_private', false)
              .order('follower_count', ascending: false)
              .limit(30),
        ]);

        final pinIds = List<Map<String, dynamic>>.from(first[0] as List)
            .map((r) => r['list_id'].toString())
            .toList();
        final followIds = List<Map<String, dynamic>>.from(first[1] as List)
            .map((r) => r['list_id'].toString())
            .toSet();
        final editorIds = List<Map<String, dynamic>>.from(first[2] as List)
            .map((r) => r['list_id'].toString())
            .toSet();
        final owned = List<Map<String, dynamic>>.from(first[3] as List);
        final discoverRows = List<Map<String, dynamic>>.from(first[4] as List);

        final byId = <String, Map<String, dynamic>>{};
        for (final row in [...owned, ...discoverRows]) {
          byId[row['id'].toString()] = row;
        }

        // Pinned, followed and collaborated lists that were not in the first
        // two queries. RLS hides any the user can no longer see.
        final missing = {...pinIds, ...followIds, ...editorIds}
            .where((id) => !byId.containsKey(id))
            .toList();
        if (missing.isNotEmpty) {
          final extra = List<Map<String, dynamic>>.from(
            await _db.from('lists').select(_listColumns).inFilter('id', missing),
          );
          for (final row in extra) {
            byId[row['id'].toString()] = row;
          }
        }

        final people =
            await _people(byId.values.map((r) => r['owner_id'].toString()));

        SwiflyList build(Map<String, dynamic> row) {
          final list = SwiflyList.fromRow(row);
          final owner = people[list.ownerId];
          list.isOwner = list.ownerId == me;
          list.isEditor = editorIds.contains(list.id);
          list.isFollowing = followIds.contains(list.id);
          list.isPinned = pinIds.contains(list.id);
          list.ownerName = owner?.name;
          list.ownerHandle = owner?.handle;
          list.ownerAvatar = owner?.avatar;
          return list;
        }

        final pinned = [
          for (final id in pinIds)
            if (byId[id] != null) build(byId[id]!),
        ];
        final yours = byId.values
            .where((r) {
              final id = r['id'].toString();
              return r['owner_id'].toString() == me ||
                  followIds.contains(id) ||
                  editorIds.contains(id);
            })
            .map(build)
            .toList();
        final discover = discoverRows
            .map(build)
            .where((list) => !list.isOwner)
            .toList();

        return ListsOverview(pinned: pinned, discover: discover, yours: yours);
      });

  /// One list with the signed-in user's relationship to it. Null if the list
  /// does not exist or the user cannot see it.
  Future<SwiflyList?> fetchList(String listId) => _run('Open list', () async {
        final me = _me ?? '';
        final rows = List<Map<String, dynamic>>.from(
          await _db
              .from('lists')
              .select(_listColumns)
              .eq('id', listId)
              .limit(1),
        );
        if (rows.isEmpty) return null;

        final list = SwiflyList.fromRow(rows.first);
        final results = await Future.wait<dynamic>([
          _people([list.ownerId]),
          _db
              .from('list_follows')
              .select('list_id')
              .eq('list_id', listId)
              .eq('user_id', me),
          _db
              .from('list_pins')
              .select('list_id')
              .eq('list_id', listId)
              .eq('user_id', me),
          _db
              .from('list_editors')
              .select('list_id')
              .eq('list_id', listId)
              .eq('user_id', me),
        ]);

        final owner = (results[0] as Map<String, ListPerson>)[list.ownerId];
        list.isOwner = list.ownerId == me;
        list.isFollowing = (results[1] as List).isNotEmpty;
        list.isPinned = (results[2] as List).isNotEmpty;
        list.isEditor = (results[3] as List).isNotEmpty;
        list.ownerName = owner?.name;
        list.ownerHandle = owner?.handle;
        list.ownerAvatar = owner?.avatar;
        return list;
      });

  Future<List<ListPerson>> fetchMembers(String listId) =>
      _run('Load members', () async {
        final rows = List<Map<String, dynamic>>.from(
          await _db
              .from('list_members')
              .select('user_id')
              .eq('list_id', listId)
              .order('created_at', ascending: false),
        );
        final ids = rows.map((r) => r['user_id'].toString()).toList();
        final people = await _people(ids);
        return [
          for (final id in ids)
            if (people[id] != null) people[id]!,
        ];
      });

  Future<List<ListPerson>> fetchEditors(String listId) =>
      _run('Load collaborators', () async {
        final rows = List<Map<String, dynamic>>.from(
          await _db
              .from('list_editors')
              .select('user_id')
              .eq('list_id', listId)
              .order('created_at', ascending: false),
        );
        final ids = rows.map((r) => r['user_id'].toString()).toList();
        final people = await _people(ids);
        return [
          for (final id in ids)
            if (people[id] != null) people[id]!,
        ];
      });

  /// The list's timeline: recent posts from its members. Posts the signed-in
  /// user cannot see (for example, followers-only posts from someone they do
  /// not follow) are left out by RLS, as everywhere else in the app.
  Future<List<FeedModel>> fetchTimeline(String listId) =>
      _run('Load list posts', () async {
        final rows = List<Map<String, dynamic>>.from(
          await _db.from('list_members').select('user_id').eq('list_id', listId),
        );
        final authorIds = rows.map((r) => r['user_id'].toString()).toList();
        if (authorIds.isEmpty) return <FeedModel>[];

        final posts = List<Map<String, dynamic>>.from(
          await _db
              .from('posts')
              .select(_postColumns)
              .inFilter('author_id', authorIds)
              .order('created_at', ascending: false)
              .limit(60),
        );
        return SupabaseRepository.instance.hydratePosts(posts);
      });

  /// People matching a name or username, excluding the signed-in user.
  Future<List<ListPerson>> searchPeople(String text) =>
      _run('Search people', () async {
        final me = _me;
        final q = text.trim().replaceAll(RegExp(r'[%,()*]'), '');
        if (q.isEmpty) return <ListPerson>[];
        final rows = List<Map<String, dynamic>>.from(
          await _db
              .from('profiles')
              .select('id, username, display_name, avatar_url')
              .or('username.ilike.%$q%,display_name.ilike.%$q%')
              .limit(25),
        );
        return rows
            .where((r) => r['id'].toString() != me)
            .map(ListPerson.fromRow)
            .toList();
      });

  // ---------------------------------------------------------------------------
  // Writes (each one is a database function that checks the rules)
  // ---------------------------------------------------------------------------

  Future<String> createList({
    required String name,
    required String description,
    required String icon,
    String? coverUrl,
    required bool isPrivate,
  }) =>
      _run('Create list', () async {
        final id = await _db.rpc('swifly_create_list', params: {
          'p_name': name,
          'p_description': description,
          'p_icon': icon,
          'p_cover_url': coverUrl ?? '',
          'p_is_private': isPrivate,
        });
        return id.toString();
      });

  /// [coverUrl] '' removes the cover; a URL replaces it.
  Future<void> updateList(
    String listId, {
    required String name,
    required String description,
    required String icon,
    required String coverUrl,
    required bool isPrivate,
  }) =>
      _run('Save list', () async {
        await _db.rpc('swifly_update_list', params: {
          'p_list': listId,
          'p_name': name,
          'p_description': description,
          'p_icon': icon,
          'p_cover_url': coverUrl,
          'p_is_private': isPrivate,
        });
      });

  Future<void> deleteList(String listId) => _run('Delete list', () async {
        await _db.rpc('swifly_delete_list', params: {'p_list': listId});
      });

  Future<void> addMember(String listId, String userId) =>
      _run('Add to list', () async {
        await _db.rpc('swifly_add_list_member', params: {
          'p_list': listId,
          'p_user': userId,
        });
      });

  Future<void> removeMember(String listId, String userId) =>
      _run('Remove from list', () async {
        await _db.rpc('swifly_remove_list_member', params: {
          'p_list': listId,
          'p_user': userId,
        });
      });

  Future<void> setEditor(String listId, String userId, {required bool on}) =>
      _run('Update collaborators', () async {
        await _db.rpc('swifly_set_list_editor', params: {
          'p_list': listId,
          'p_user': userId,
          'p_on': on,
        });
      });

  Future<void> setFollow(String listId, {required bool follow}) =>
      _run('Follow list', () async {
        await _db.rpc('swifly_set_list_follow', params: {
          'p_list': listId,
          'p_follow': follow,
        });
      });

  Future<void> setPin(String listId, {required bool pinned}) =>
      _run('Pin list', () async {
        await _db.rpc('swifly_set_list_pin', params: {
          'p_list': listId,
          'p_pinned': pinned,
        });
      });

  Future<String> uploadCover(File file) => _run(
        'Upload cover',
        () => SupabaseRepository.instance.uploadFile(kCoversBucket, file),
      );
}
