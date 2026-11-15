import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/app_empty_state.dart';
import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/chatModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/chats/chatState.dart';
import 'package:flutter_twitter_clone/state/searchState.dart';
import 'package:flutter_twitter_clone/ui/page/profile/profilePage.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/customWidgets.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/emptyList.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/rippleButton.dart';
import 'package:flutter_twitter_clone/widgets/newWidget/title_text.dart';
import 'package:flutter_twitter_clone/widgets/verified_badge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class ChatListPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ChatListPage({Key? key, required this.scaffoldKey}) : super(key: key);
  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  /// Other users' ids of the selected conversations. Selection mode is on
  /// while at least one conversation is selected.
  final Set<String> _selected = <String>{};
  bool _deleting = false;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final state = Provider.of<AuthState>(context, listen: false);
    chatState.setIsChatScreenOpen = true;
    chatState.getUserChatList(state.user!.uid);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) context.read<SearchState>().resetFilterList();
  }

  void _openChat(UserModel model) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final searchState = Provider.of<SearchState>(context, listen: false);
    chatState.setChatUser = model;
    if (searchState.userlist!.any((x) => x.userId == model.userId)) {
      chatState.setChatUser =
          searchState.userlist!.where((x) => x.userId == model.userId).first;
    }
    Navigator.pushNamed(context, '/ChatScreenPage');
  }

  void _startSelection(String id) {
    HapticFeedback.mediumImpact();
    setState(() => _selected.add(id));
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _confirmDelete() async {
    final count = _selected.length;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _DeleteConversationsDialog(count: count),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final ids = _selected.toList();
    setState(() => _deleting = true);
    try {
      await Provider.of<ChatState>(context, listen: false)
          .deleteConversations(ids);
      if (mounted) setState(() => _selected.clear());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't delete. Check your connection and try again."),
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void onSettingIconPressed() {
    Navigator.pushNamed(context, '/DirectMessagesPage');
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final selecting = _selecting;
    final avatar = Provider.of<AuthState>(context).userModel?.profilePic;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.blue),
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: selecting
            ? IconButton(
                key: const ValueKey('close-selection'),
                icon: const Icon(LucideIcons.x, color: AppColor.primary),
                onPressed: _clearSelection,
              )
            : Padding(
                key: const ValueKey('avatar'),
                padding: const EdgeInsets.all(10),
                child: CircularImage(path: avatar, height: 30).ripple(() {
                  widget.scaffoldKey.currentState?.openDrawer();
                }),
              ),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: selecting
            ? KeyedSubtree(
                key: const ValueKey('count'),
                child: TitleText('${_selected.length} selected', fontSize: 18),
              )
            : KeyedSubtree(
                key: const ValueKey('title'),
                child: customTitleText('Messages'),
              ),
      ),
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.5, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: selecting
              ? IconButton(
                  key: const ValueKey('discard'),
                  tooltip: 'Delete selected',
                  icon: const Icon(LucideIcons.trash2, color: Colors.red),
                  onPressed: _deleting ? null : _confirmDelete,
                )
              : IconButton(
                  key: const ValueKey('gear'),
                  tooltip: 'Message settings',
                  icon: const Icon(LucideIcons.settings,
                      color: AppColor.primary, size: 25),
                  onPressed: onSettingIconPressed,
                ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade200),
      ),
    );
  }

  Widget _body() {
    final state = Provider.of<ChatState>(context);
    final searchState = Provider.of<SearchState>(context, listen: false);
    final list = state.chatUserList;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: AppEmptyState(
          'No message available ',
          subTitle:
              'When someone sends you message,UserModel list\'ll show up here \n  To send message tap message button.',
        ),
      );
    }
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: AppEmptyState(
          'No messages yet',
          subTitle:
              'Your conversations will show up here. Tap the message button to start one.',
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final last = list[index];
        final model = searchState.userlist!.firstWhere(
          (x) => x.userId == last.key,
          orElse: () => UserModel(userName: 'Unknown'),
        );
        return _conversationRow(model, last);
      },
    );
  }

  Widget _selectionDot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColor.primary : Colors.white,
        border: Border.all(
          color: selected ? AppColor.primary : AppColor.lightGrey,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: const Icon(LucideIcons.check, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _conversationRow(UserModel model, ChatMessage? lastMessage) {
    final id = model.userId;
    final selecting = _selecting;
    final selected = id != null && _selected.contains(id);

    return Material(
      color: selected ? AppColor.extraExtraLightGrey : Colors.white,
      child: InkWell(
        onTap: id == null
            ? null
            : () => selecting ? _toggle(id) : _openChat(model),
        onLongPress:
            id == null || selecting ? null : () => _startSelection(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              // Left gutter: grows to make room for the selection circle, which
              // pushes the conversation to the right.
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: selecting ? 34 : 0,
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 34,
                    maxWidth: 34,
                    child: _selectionDot(selected),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSlide(
                  offset: Offset(selected ? 0.02 : 0, 0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _rowContent(model, lastMessage, selecting),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowContent(UserModel model, ChatMessage? lastMessage, bool selecting) {
    final verified = model.isVerified ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IgnorePointer(
          ignoring: selecting,
          child: RippleButton(
            onPressed: () {
              Navigator.push(
                  context, ProfilePage.getRoute(profileId: model.userId!));
            },
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(28),
                image: DecorationImage(
                  image: customAdvanceNetworkImage(
                    model.profilePic ?? Constants.dummyProfilePic,
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: TitleText(
                      model.displayName ?? 'NA',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 14),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              customText(
                getLastMessage(lastMessage?.message) ??
                    '@${model.displayName}',
                style: TextStyles.onPrimarySubTitleText
                    .copyWith(color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (lastMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              Utility.getChatTime(lastMessage.createdAt).toString(),
              style: TextStyles.onPrimarySubTitleText.copyWith(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  FloatingActionButton _newMessageButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).pushNamed('/NewMessagePage');
      },
      child: customIcon(
        context,
        icon: AppIcon.newMessage,
        isTwitterIcon: false,
        iconColor: Theme.of(context).colorScheme.onPrimary,
        size: 25,
      ),
    );
  }

  String? getLastMessage(String? message) {
    if (message != null && message.isNotEmpty) {
      if (message.length > 100) {
        return message.substring(0, 80) + '...';
      }
      return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Back leaves selection mode first instead of leaving the screen.
        if (_selecting) {
          _clearSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _appBar(context),
        floatingActionButton: _selecting ? null : _newMessageButton(),
        backgroundColor: TwitterColor.mystic,
        body: _body(),
      ),
    );
  }
}

class _DeleteConversationsDialog extends StatelessWidget {
  const _DeleteConversationsDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final one = count == 1;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleText(
                one
                    ? 'Delete conversation?'
                    : 'Delete $count conversations?',
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              const SizedBox(height: 10),
              Text(
                one
                    ? 'Are you sure you want to delete this conversation? It will be removed from your Messages.'
                    : 'Are you sure you want to delete these $count conversations? They will be removed from your Messages.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColor.darkGrey,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.extraLightGrey,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Yes, delete',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
