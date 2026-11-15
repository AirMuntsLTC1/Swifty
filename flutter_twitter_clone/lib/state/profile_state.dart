import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Profile page state: the signed-in user and the profile being viewed.
class ProfileState extends ChangeNotifier {
  ProfileState(this.profileId) {
    userId = SupabaseRepository.instance.uid ?? '';
    databaseInit();
    _getloggedInUserProfile(userId);
    _getProfileUser(profileId);
  }

  /// Id of the logged-in user.
  late String userId;

  /// Profile data of the logged-in user.
  UserModel _userModel = UserModel(followersList: [], followingList: []);
  UserModel get userModel => _userModel;

  /// Id of the profile being viewed.
  final String profileId;

  /// Profile data of the user whose profile is open.
  UserModel _profileUserModel = UserModel(followersList: [], followingList: []);
  UserModel get profileUserModel => _profileUserModel;

  RealtimeChannel? _channel;

  bool _isBusy = true;
  bool get isbusy => _isBusy;
  set loading(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  SupabaseRepository get _repo => SupabaseRepository.instance;

  /// Refresh counts when the follow graph changes.
  void databaseInit() {
    if (_channel != null) return;
    _channel = _repo.db.channel('profile-view-$profileId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        callback: (_) {
          _refreshProfiles();
        },
      )
      ..subscribe();
  }

  bool get isMyProfile => profileId == userId;

  Future<void> _getloggedInUserProfile(String userId) async {
    final model = await _repo.fetchUser(userId);
    if (model != null) {
      _userModel = model;
      notifyListeners();
    }
  }

  Future<void> _getProfileUser(String? userProfileId) async {
    if (userProfileId == null) return;
    try {
      loading = true;
      final model = await _repo.fetchUser(userProfileId);
      if (model != null) {
        _profileUserModel = model;
        Utility.logEvent('get_profile', parameter: {});
      }
    } catch (error) {
      cprint(error, errorIn: 'getProfileUser');
    } finally {
      loading = false;
    }
  }

  Future<void> _refreshProfiles() async {
    await _getloggedInUserProfile(userId);
    final model = await _repo.fetchUser(profileId);
    if (model != null) {
      _profileUserModel = model;
      notifyListeners();
    }
  }

  /// Follow / unfollow the profile user. The database trigger
  /// `swifly_on_follow` creates the follow notification.
  Future<void> followUser({bool removeFollower = false}) async {
    try {
      final me = userModel.userId ?? userId;
      final target = profileUserModel.userId ?? profileId;
      final unfollow = removeFollower;

      await _repo.setFollow(target, follow: !unfollow);

      final targetFollowers = _profileUserModel.followersList ??= [];
      final myFollowing = _userModel.followingList ??= [];
      if (unfollow) {
        targetFollowers.remove(me);
        myFollowing.remove(target);
      } else {
        if (!targetFollowers.contains(me)) targetFollowers.add(me);
        if (!myFollowing.contains(target)) myFollowing.add(target);
      }
      _profileUserModel.followers = targetFollowers.length;
      _userModel.following = myFollowing.length;
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'followUser');
    }
  }

  /// Reloads the profile shown on this page, for example after Edit Profile
  /// saves a new name, photo or cover.
  Future<void> refreshProfile() async {
    await _getloggedInUserProfile(userId);
    await _getProfileUser(profileId);
    notifyListeners();
  }

  /// Kept for compatibility. The follow notification is created by a trigger.
  void addFollowNotification() {}

  @override
  void dispose() {
    if (_channel != null) {
      _repo.db.removeChannel(_channel!);
      _channel = null;
    }
    super.dispose();
  }
}




