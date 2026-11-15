import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// "Who to follow" suggestions shown after sign-up.
class SuggestionsState extends AppState {
  List<UserModel>? _userlist;

  UserModel? currentUser;
  void initUser(UserModel? model) {
    if (model != null && currentUser != model) {
      currentUser = model;
      _displaySuggestions = int.tryParse(currentUser!.getFollowing)! < 5;
    }
  }

  bool _displaySuggestions = false;
  bool get displaySuggestions => _displaySuggestions;
  set displaySuggestions(bool value) {
    if (value != _displaySuggestions) {
      _displaySuggestions = value;
      notifyListeners();
    }
  }

  List<UserModel>? get userlist => _userlist;
  void setUserlist(List<UserModel>? list) {
    if (list != null && _userlist == null) {
      list.sort((a, b) => (b.followersList?.length ?? 0)
          .compareTo(a.followersList?.length ?? 0));
      _userlist = list.take(20).toList();
      _userlist!.removeWhere((element) => isFollowing(element));
      _selectedUsers = List.from(_userlist!);
    }
  }

  /// True if the signed-in user already follows [user].
  bool isFollowing(UserModel user) {
    return user.followersList?.contains(currentUser?.userId) ?? false;
  }

  List<UserModel> _selectedUsers = [];
  int get selectedUsersCount => _selectedUsers.length;

  bool isSelected(UserModel user) => _selectedUsers.contains(user);

  void toggleAllSelections() {
    if (_selectedUsers.length == (_userlist?.length ?? 0)) {
      _selectedUsers = [];
    } else {
      _selectedUsers = List.from(_userlist ?? const []);
    }
    notifyListeners();
  }

  void toggleUserSelection(UserModel user) {
    if (isSelected(user)) {
      _selectedUsers.remove(user);
    } else {
      _selectedUsers.add(user);
    }
    notifyListeners();
  }

  /// Load users to suggest.
  Future<void> getDataFromDatabase() async {
    try {
      final users = await SupabaseRepository.instance.fetchAllUsers();
      setUserlist(users);
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'getDataFromDatabase');
    }
  }

  /// Follow every selected user.
  Future<void> followUsers() async {
    try {
      if (_selectedUsers.isEmpty) return;
      final repo = SupabaseRepository.instance;
      final me = currentUser;
      for (final user in _selectedUsers) {
        if (user.userId == null) continue;
        await repo.setFollow(user.userId!, follow: true);
        user.followersList ??= [];
        if (me?.userId != null && !user.followersList!.contains(me!.userId)) {
          user.followersList!.add(me.userId!);
        }
        user.followers = user.followersList!.length;
      }
      if (me != null) {
        me.followingList ??= [];
        for (final user in _selectedUsers) {
          if (user.userId != null && !me.followingList!.contains(user.userId)) {
            me.followingList!.add(user.userId!);
          }
        }
        me.following = me.followingList!.length;
      }
      displaySuggestions = false;
    } catch (error) {
      cprint(error, errorIn: 'followUsers');
    }
  }
}
