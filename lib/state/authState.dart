import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/shared_prefrence_helper.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/resource/push_notification_service.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_auth_service.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/common/locator.dart';

/// The signed-in Supabase user as the UI sees it.
class SwiflyUser {
  SwiflyUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;
}

/// Login session, the signed-in user's profile, and profile updates.
/// Auth is handled by the `email-code-auth` Edge Function through
/// [SupabaseAuthService]; profile data comes from the `profiles` table.
class AuthState extends AppState {
  AuthStatus authStatus = AuthStatus.NOT_DETERMINED;
  bool isSignInWithGoogle = false;
  SwiflyUser? user;

  String get userId => user?.uid ?? SupabaseRepository.instance.uid ?? '';

  UserModel? _userModel;
  RealtimeChannel? _profileChannel;

  UserModel? get userModel => _userModel;
  UserModel? get profileUserModel => _userModel;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  /// Logout from device.
  void logoutCallback() async {
    authStatus = AuthStatus.NOT_LOGGED_IN;
    _userModel = null;
    user = null;
    isSignInWithGoogle = false;
    await _removeProfileChannel();
    notifyListeners();
    try {
      await SupabaseAuthService.instance.signOut();
    } catch (error) {
      cprint(error, errorIn: 'logoutCallback');
    }
    await getIt<SharedPreferenceHelper>().clearPreferenceValues();
  }

  /// Alter select auth method, login and sign up page.
  void openSignUpPage() {
    authStatus = AuthStatus.NOT_LOGGED_IN;
    notifyListeners();
  }

  /// Subscribe to changes of the signed-in user's profile row.
  void databaseInit() {
    final me = _repo.uid;
    if (me == null || _profileChannel != null) return;
    _profileChannel = _repo.db.channel('profile-me-$me')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: me,
        ),
        callback: (_) {
          getProfileUser();
        },
      )
      ..subscribe();
  }

  /// Email + password sign in.
  Future<String?> signIn(String email, String password,
      {required BuildContext context}) async {
    try {
      isBusy = true;
      await SupabaseAuthService.instance.login(email: email, password: password);
      final current = await getCurrentUser();
      return current?.uid;
    } on SwiflyAuthError catch (error) {
      Utility.customSnackBar(context, error.message);
      return null;
    } catch (error) {
      Utility.customSnackBar(context, error.toString());
      return null;
    } finally {
      isBusy = false;
    }
  }

  /// Google sign-in is not connected to Supabase in this build.
  Future<SwiflyUser?> handleGoogleSignIn() async {
    cprint('Google sign-in is not connected. Use email sign-in.',
        errorIn: 'handleGoogleSignIn');
    return null;
  }

  /// Sign-up is done on the code-verified screen (create_account_page.dart).
  Future<String?> signUp(UserModel userModel,
      {required BuildContext context, required String password}) async {
    Utility.customSnackBar(
      context,
      'Create your account from the sign-up screen.',
    );
    return null;
  }

  /// Save profile fields for the signed-in user.
  Future<void> createUser(UserModel user, {bool newUser = false}) async {
    try {
      await _repo.updateProfile(
        displayName: user.displayName,
        bio: user.bio,
      );
      _userModel = user;
    } catch (error) {
      cprint(error, errorIn: 'createUser');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Load the signed-in user and their profile.
  Future<SwiflyUser?> getCurrentUser() async {
    try {
      isBusy = true;
      final auth = _repo.db.auth.currentUser;
      if (auth == null) {
        authStatus = AuthStatus.NOT_LOGGED_IN;
        user = null;
        return null;
      }
      user = SwiflyUser(
        uid: auth.id,
        email: auth.email,
        displayName: (auth.userMetadata?['display_name'] ?? '').toString(),
        emailVerified: auth.emailConfirmedAt != null,
      );
      await _repo.ensureOwnProfile();
      await getProfileUser();
      authStatus = AuthStatus.LOGGED_IN;
      databaseInit();
      return user;
    } catch (error) {
      authStatus = AuthStatus.NOT_LOGGED_IN;
      cprint(error, errorIn: 'getCurrentUser');
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Email verification happens with the 6-digit code at sign-up.
  void reloadUser() {}

  Future<void> sendEmailVerification(BuildContext context) async {
    Utility.customSnackBar(
      context,
      'Your email was verified with a code when you created your account.',
    );
  }

  /// Accounts are only created after the email code is verified.
  Future<bool> emailVerified() async => user?.emailVerified ?? false;

  /// Send a 6-digit reset code. The reset screen completes the change.
  Future<void> forgetPassword(String email,
      {required BuildContext context}) async {
    try {
      await SupabaseAuthService.instance
          .sendCode(email: email, purpose: 'password_reset');
      Utility.customSnackBar(
          context, 'A 6-digit reset code was sent to your email.');
    } on SwiflyAuthError catch (error) {
      Utility.customSnackBar(context, error.message);
    }
  }

  /// Update display name, bio and avatar for the signed-in user.
  Future<void> updateUserProfile(UserModel? userModel,
      {File? image, File? bannerImage}) async {
    try {
      final target = userModel ?? _userModel;
      if (target == null) return;

      String? avatarUrl;
      if (image != null) {
        avatarUrl = await _repo.uploadFile(kAvatarBucket, image);
        target.profilePic = avatarUrl;
        Utility.logEvent('user_profile_image');
      }
      if (bannerImage != null) {
        cprint('Banner images are not stored in the Supabase schema yet.');
      }

      await _repo.updateProfile(
        displayName: target.displayName,
        bio: target.bio,
        avatarUrl: avatarUrl,
      );
      await getProfileUser();
      Utility.logEvent('update_user');
    } catch (error) {
      cprint(error, errorIn: 'updateUserProfile');
    }
  }

  /// Fetch a user's profile by id.
  Future<UserModel?> getUserDetail(String userId) => _repo.fetchUser(userId);

  /// Fetch the signed-in user's profile when [userProfileId] is null.
  Future<void> getProfileUser({String? userProfileId}) async {
    try {
      final me = _repo.uid;
      if (me == null) return;
      final id = userProfileId ?? me;
      final model = await _repo.fetchUser(id);
      if (model != null && id == me) {
        _userModel = model;
        _syncUser();
        getIt<SharedPreferenceHelper>().saveUserProfile(_userModel!);
        notifyListeners();
      }
    } catch (error) {
      cprint(error, errorIn: 'getProfileUser');
    } finally {
      isBusy = false;
    }
  }

  /// Register this device's push token so the server can send notifications.
  void updateFCMToken() {
    if (_userModel == null) return;
    PushNotificationService.registerCurrentDeviceToken();
  }

  void _syncUser() {
    final auth = _repo.db.auth.currentUser;
    if (auth == null) return;
    user = SwiflyUser(
      uid: auth.id,
      email: auth.email,
      displayName: _userModel?.displayName,
      photoURL: _userModel?.profilePic,
      emailVerified: auth.emailConfirmedAt != null,
    );
  }

  Future<void> _removeProfileChannel() async {
    if (_profileChannel != null) {
      await _repo.db.removeChannel(_profileChannel!);
      _profileChannel = null;
    }
  }

  @override
  void dispose() {
    _removeProfileChannel();
    super.dispose();
  }
}
