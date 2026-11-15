import 'package:material_ui/material_ui.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/notificationModel.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/notificationState.dart';
import 'package:flutter_twitter_clone/state/badgeState.dart';
import 'package:flutter_twitter_clone/ui/page/notification/widget/activity_notification_tile.dart';
import 'package:flutter_twitter_clone/ui/page/notification/widget/follow_notification_tile.dart';
import 'package:flutter_twitter_clone/ui/page/notification/widget/list_add_notification_tile.dart';
import 'package:flutter_twitter_clone/ui/page/notification/widget/post_like_tile.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/customAppBar.dart';
import 'package:flutter_twitter_clone/widgets/customWidgets.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/emptyList.dart';
import 'package:provider/provider.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key, required this.scaffoldKey})
      : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = Provider.of<NotificationState>(context, listen: false);
      final authState = Provider.of<AuthState>(context, listen: false);
      state.databaseInit(authState.userId);
      state.getDataFromDatabase(authState.userId, force: true);
      Provider.of<BadgeState>(context, listen: false).clearNotifications();
    });
  }

  void onSettingIconPressed() {
    Navigator.pushNamed(context, '/NotificationPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwitterColor.mystic,
      appBar: CustomAppBar(
        scaffoldKey: widget.scaffoldKey,
        title: customTitleText('Notifications'),
        icon: AppIcon.settings,
        onActionPressed: onSettingIconPressed,
      ),
      body: const NotificationPageBody(),
    );
  }
}

class NotificationPageBody extends StatelessWidget {
  const NotificationPageBody({Key? key}) : super(key: key);

  Widget _notificationRow(BuildContext context, NotificationModel model) {
    final state = Provider.of<NotificationState>(context);
    final data = model.data ?? <String, dynamic>{};
    if (data['genericActivity'] == true) {
      return ActivityNotificationTile(model: model);
    }
    if (model.type == NotificationType.ListActivity.toString()) {
      return ListAddNotificationTile(model: model);
    }
    if (model.type == NotificationType.Follow.toString()) {
      return FollowNotificationTile(model: model);
    }
    if (model.tweetKey == null) {
      return ActivityNotificationTile(model: model);
    }
    return FutureBuilder<FeedModel?>(
      future: state.getTweetDetail(model.tweetKey!),
      builder: (BuildContext context, AsyncSnapshot<FeedModel?> snapshot) {
        if (snapshot.hasData) {
          return PostLikeTile(model: snapshot.data!);
        } else if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.active) {
          return const SizedBox(
            height: 4,
            child: LinearProgressIndicator(),
          );
        } else {
          final authState = Provider.of<AuthState>(context, listen: false);
          state.removeNotification(authState.userId, model.tweetKey!);
          return const SizedBox();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<NotificationState>(context);
    final list = state.notificationList;
    if (state.isbusy) {
      return const SizedBox(
        height: 3,
        child: LinearProgressIndicator(),
      );
    }
    if (list == null || list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: EmptyList(
          'No Notification available yet',
          subTitle: 'When new notification found, they\'ll show up here.',
        ),
      );
    }
    return ListView.builder(
      addAutomaticKeepAlives: true,
      itemBuilder: (context, index) => _notificationRow(context, list[index]),
      itemCount: list.length,
    );
  }
}
