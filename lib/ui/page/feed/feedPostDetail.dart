import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/customWidgets.dart';
import 'package:flutter_twitter_clone/widgets/tweet/tweet.dart';
import 'package:flutter_twitter_clone/widgets/tweet/widgets/tweetBottomSheet.dart';
import 'package:provider/provider.dart';

class FeedPostDetail extends StatefulWidget {
  const FeedPostDetail({Key? key, required this.postId}) : super(key: key);
  final String postId;

  static Route<void> getRoute(String postId) {
    return SlideLeftRoute<void>(
      builder: (BuildContext context) => FeedPostDetail(
        postId: postId,
      ),
    );
  }

  @override
  _FeedPostDetailState createState() => _FeedPostDetailState();
}

class _FeedPostDetailState extends State<FeedPostDetail> {
  late String postId;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  void initState() {
    postId = widget.postId;
    super.initState();
  }

  Widget _floatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        var state = Provider.of<FeedState>(context, listen: false);
        state.setTweetToReply = state.tweetDetailModel!.last;
        Navigator.of(context).pushNamed('/ComposeTweetPage/' + postId);
      },
      child: const Icon(LucideIcons.plus),
    );
  }

  Widget _commentRow(FeedModel model) {
    return Tweet(
      model: model,
      type: TweetType.Reply,
      trailing: TweetBottomSheet().tweetOptionIcon(context,
          scaffoldKey: scaffoldKey, model: model, type: TweetType.Reply),
      scaffoldKey: scaffoldKey,
    );
  }

  Widget _tweetDetail(FeedModel model) {
    return Tweet(
      model: model,
      type: TweetType.Detail,
      trailing: TweetBottomSheet().tweetOptionIcon(context,
          scaffoldKey: scaffoldKey, model: model, type: TweetType.Detail),
      scaffoldKey: scaffoldKey,
    );
  }

  void addLikeToComment(String commentId) {
    var state = Provider.of<FeedState>(context, listen: false);
    var authState = Provider.of<AuthState>(context, listen: false);
    state.addLikeToTweet(state.tweetDetailModel!.last, authState.userId);
  }

  void openImage() async {
    Navigator.pushNamed(context, '/ImageViewPge');
  }

  void deleteTweet(TweetType type, String tweetId,
      {required String parentkey}) {
    var state = Provider.of<FeedState>(context, listen: false);
    state.deleteTweet(tweetId, type, parentkey: parentkey);
    Navigator.of(context).pop();
    if (type == TweetType.Detail) Navigator.of(context).pop();
  }

  Widget _detailArea(FeedState state) {
    final matches = (state.tweetDetailModel ?? const <FeedModel>[])
        .where((x) => x.key == postId)
        .toList();
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: SwiflyLoader()),
      );
    }
    return _tweetDetail(matches.last);
  }

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<FeedState>(context);
    return WillPopScope(
      onWillPop: () async {
        Provider.of<FeedState>(context, listen: false)
            .removeLastTweetDetail(postId);
        return Future.value(true);
      },
      child: Scaffold(
        key: scaffoldKey,
        floatingActionButton: _floatingActionButton(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              title: customTitleText(
                'Thread',
              ),
              iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              bottom: PreferredSize(
                child: Container(
                  color: Colors.grey.shade200,
                  height: 1.0,
                ),
                preferredSize: const Size.fromHeight(0.0),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  _detailArea(state),
                  Container(
                    height: 6,
                    width: double.infinity,
                    color: TwitterColor.mystic,
                  )
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                state.tweetReplyMap == null ||
                        state.tweetReplyMap!.isEmpty ||
                        state.tweetReplyMap![postId] == null
                    ? [
                        //!Removed container
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: SwiflyLoader()),
                        )
                      ]
                    : state.tweetReplyMap![postId]!.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No replies yet',
                                  style: TextStyle(color: Color(0xff657786)),
                                ),
                              ),
                            )
                          ]
                        : state.tweetReplyMap![postId]!
                            .map((x) => _commentRow(x))
                            .toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}




