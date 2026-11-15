import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/push_notification_model.dart';
import 'package:flutter_twitter_clone/resource/push_notification_service.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/chats/chatState.dart';
import 'package:flutter_twitter_clone/state/badgeState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:flutter_twitter_clone/state/notificationState.dart';
import 'package:flutter_twitter_clone/state/searchState.dart';
import 'package:flutter_twitter_clone/state/suggestionUserState.dart';
import 'package:flutter_twitter_clone/ui/page/feed/feedPage.dart';
import 'package:flutter_twitter_clone/ui/page/feed/feedPostDetail.dart';
import 'package:flutter_twitter_clone/ui/page/feed/suggestedUsers.dart';
import 'package:flutter_twitter_clone/ui/page/message/chatListPage.dart';
import 'package:flutter_twitter_clone/widgets/bottomMenuBar/bottomMenuBar.dart';
import 'package:provider/provider.dart';

import 'common/locator.dart';
import 'common/sidebar.dart';
import 'notification/notificationPage.dart';
import 'search/SearchPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  int pageIndex = 0;
  StreamSubscription<PushNotificationModel>? pushNotificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Provider.of<AppState>(context, listen: false).setPageIndex = 0;

      // Load the signed-in user first; the other states use its id.
      final authState = Provider.of<AuthState>(context, listen: false);
      await authState.getCurrentUser();
      if (!mounted) return;

      initTweets();
      initProfile();
      initSearch();
      initNotification();
      initChat();
    });
  }

  @override
  void dispose() {
    pushNotificationSubscription?.cancel();
    super.dispose();
  }

  void initTweets() {
    final state = Provider.of<FeedState>(context, listen: false);
    state.databaseInit();
    state.getDataFromDatabase();
  }

  void initProfile() {
    final state = Provider.of<AuthState>(context, listen: false);
    state.databaseInit();
  }

  void initSearch() {
    final searchState = Provider.of<SearchState>(context, listen: false);
    searchState.getDataFromDatabase();
  }

  void initNotification() {
    final state = Provider.of<NotificationState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    state.databaseInit(authState.userId);
    state.getDataFromDatabase(authState.userId);
    Provider.of<BadgeState>(context, listen: false).start(authState.userId);

    // Start push (device token + tap handling).
    state.initFirebaseService();
    pushNotificationSubscription = getIt<PushNotificationService>()
        .pushNotificationResponseStream
        .listen(listenPushNotification);
  }

  /// Push taps: messages open the chat tab, mentions open the post,
  /// everything else opens the notifications tab.
  void listenPushNotification(PushNotificationModel model) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (model.type == NotificationType.Message.toString()) {
      appState.setPageIndex = 3;
    } else if (model.type == NotificationType.Mention.toString() &&
        model.tweetId.isNotEmpty) {
      final feedState = Provider.of<FeedState>(context, listen: false);
      feedState.getPostDetailFromDatabase(model.tweetId);
      Navigator.push(context, FeedPostDetail.getRoute(model.tweetId));
    } else {
      appState.setPageIndex = 2;
    }
  }

  void initChat() {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    // Inbox subscription: other user is the same as me.
    chatState.databaseInit(authState.userId, authState.userId);
    chatState.getUserChatList(authState.userId);
  }

  Widget _body() {
    return SafeArea(
      child: Container(
        child: _getPage(Provider.of<AppState>(context).pageIndex),
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return FeedPage(
          scaffoldKey: _scaffoldKey,
          refreshIndicatorKey: refreshIndicatorKey,
        );
      case 1:
        return SearchPage(scaffoldKey: _scaffoldKey);
      case 2:
        return NotificationPage(scaffoldKey: _scaffoldKey);
      case 3:
        return ChatListPage(scaffoldKey: _scaffoldKey);
      default:
        return FeedPage(
          scaffoldKey: _scaffoldKey,
          refreshIndicatorKey: refreshIndicatorKey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthState>();
    context.read<SuggestionsState>().initUser(state.userModel);

    if (context
        .select<SuggestionsState, bool>((state) => state.displaySuggestions)) {
      return SuggestedUsers();
    }

    return Scaffold(
      key: _scaffoldKey,
      bottomNavigationBar: const BottomMenubar(),
      drawer: const SidebarMenu(),
      body: _body(),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<StreamSubscription<PushNotificationModel>?>(
            'pushNotificationSubscription', pushNotificationSubscription));
  }
}
