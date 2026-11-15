import 'package:flutter_twitter_clone/helper/shared_prefrence_helper.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/common/locator.dart';

enum StateType { following, follower }

/// Followers / following list of a profile.
class FollowListState extends AppState {
  FollowListState(StateType type) {
    isBusy = true;
    getIt<SharedPreferenceHelper>().getUserProfile().then((user) {
      _currentUser = user;
      isBusy = false;
      notifyListeners();
    });
    stateType = type;
  }

  UserModel? _currentUser;
  late StateType stateType;

  /// Follow / unfollow [secondUser] as the signed-in user.
  Future<void> followUser(UserModel secondUser) async {
    final me = _currentUser;
    if (me == null || me.userId == null || secondUser.userId == null) return;
    final alreadyFollowing = isFollowing(secondUser);
    try {
      await SupabaseRepository.instance
          .setFollow(secondUser.userId!, follow: !alreadyFollowing);

      final followers = secondUser.followersList ??= [];
      final following = me.followingList ??= [];
      if (alreadyFollowing) {
        followers.remove(me.userId);
        following.remove(secondUser.userId);
      } else {
        if (!followers.contains(me.userId)) followers.add(me.userId!);
        if (!following.contains(secondUser.userId)) {
          following.add(secondUser.userId!);
        }
      }
      secondUser.followers = followers.length;
      me.following = following.length;
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'followUser');
    }
  }

  /// True if the signed-in user follows [user].
  bool isFollowing(UserModel user) =>
      _currentUser?.followingList?.contains(user.userId) ?? false;

  /// Kept for compatibility. The follow trigger creates the notification.
  void addFollowNotification(String profileId) {}
}
