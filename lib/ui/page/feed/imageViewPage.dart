import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/tweet/widgets/tweetIconsRow.dart';

/// Full-screen photo previewer. Tap the photo to show or hide the controls.
/// Comments posted here go to the photo's post, like the thread does.
class ImageViewPge extends StatefulWidget {
  const ImageViewPge({Key? key, this.model}) : super(key: key);

  /// The post (or reply) whose photo is shown. When null, the current
  /// thread's post is used.
  final FeedModel? model;

  @override
  _ImageViewPgeState createState() => _ImageViewPgeState();
}

class _ImageViewPgeState extends State<ImageViewPge> {
  bool _showTools = true;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  FeedModel? _currentModel(BuildContext context) =>
      widget.model ??
      Provider.of<FeedState>(context, listen: false).tweetDetailModel?.last;

  Widget _photo(String? url) {
    if (url == null || url.isEmpty) {
      return const Center(
        child: Text('No photo', style: TextStyle(color: Colors.white)),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (context, _) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          errorWidget: (context, _, __) => const Center(
            child: Icon(LucideIcons.circleAlert, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: () => Navigator.maybePop(context),
      ),
    );
  }

  Widget _commentBar(FeedModel? model) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );
    return Container(
      color: TwitterColor.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Comment here..',
                hintStyle: TextStyle(color: TwitterColor.paleSky),
                filled: true,
                fillColor: TwitterColor.mystic,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: model == null ? null : () => _submit(model),
            icon: Icon(LucideIcons.send, color: TwitterColor.dodgeBlue),
          ),
        ],
      ),
    );
  }

  void _submit(FeedModel model) {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > 280) return;
    final state = Provider.of<FeedState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    final me = authState.userModel;
    if (me == null) return;

    final commentedUser = UserModel(
      displayName: me.displayName ?? me.userName ?? '',
      userName: me.userName,
      isVerified: me.isVerified,
      profilePic: me.profilePic,
      userId: authState.userId,
    );
    final reply = FeedModel(
      description: text,
      user: commentedUser,
      createdAt: DateTime.now().toUtc().toString(),
      tags: Utility.getHashTags(text),
      userId: commentedUser.userId!,
      parentkey: model.parentkey ?? model.key,
    );
    state.setTweetToReply = model;
    state.addCommentToPost(reply);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final model = _currentModel(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showTools = !_showTools),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: _photo(model?.imagePath)),
                    if (_showTools)
                      Positioned(top: 8, left: 8, child: _backButton()),
                  ],
                ),
              ),
            ),
            if (_showTools && model != null)
              Container(
                color: TwitterColor.white,
                child: TweetIconsRow(
                  model: model,
                  iconColor: TwitterColor.paleSky,
                  iconEnableColor: TwitterColor.ceriseRed,
                  scaffoldKey: GlobalKey<ScaffoldState>(),
                ),
              ),
            if (_showTools) _commentBar(model),
          ],
        ),
      ),
    );
  }
}
