import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';
import 'package:flutter_twitter_clone/ui/page/lists/listMemberPicker.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/page/profile/profilePage.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';
import 'package:flutter_twitter_clone/widgets/tweet/tweet.dart';
import 'package:flutter_twitter_clone/widgets/tweet/widgets/tweetBottomSheet.dart';

class ListDetailPage extends StatefulWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  /// Pops with true if the list changed, so the Lists screen reloads.
  static Route<bool> getRoute(String listId) {
    return CustomRoute<bool>(
      builder: (_) => ListDetailPage(listId: listId),
      settings: const RouteSettings(name: 'ListDetailPage'),
    );
  }

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repo = SwiflyListsRepository.instance;

  SwiflyList? _list;
  List<ListPerson> _members = [];
  List<ListPerson> _editors = [];
  List<FeedModel> _posts = [];
  bool _loading = true;
  bool _changed = false;
  bool _showMembers = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchList(widget.listId);
      if (!mounted) return;
      if (list == null) {
        setState(() => _list = null);
        return;
      }
      final results = await Future.wait<dynamic>([
        _repo.fetchMembers(widget.listId),
        _repo.fetchEditors(widget.listId),
        _repo.fetchTimeline(widget.listId),
      ]);
      if (!mounted) return;
      setState(() {
        _list = list;
        _members = results[0] as List<ListPerson>;
        _editors = results[1] as List<ListPerson>;
        _posts = results[2] as List<FeedModel>;
      });
    } catch (_) {
      // The repository has already shown the error.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {}
    _changed = true;
    await _load();
  }

  Future<void> _toggleFollow() async {
    final list = _list;
    if (list == null) return;
    await _action(() => _repo.setFollow(list.id, follow: !list.isFollowing));
  }

  Future<void> _togglePin() async {
    final list = _list;
    if (list == null) return;
    await _action(() => _repo.setPin(list.id, pinned: !list.isPinned));
  }

  Future<void> _edit() async {
    final list = _list;
    if (list == null) return;
    final edited = await Navigator.push<bool>(context, ListFormPage.getRoute(list: list));
    if (edited == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _openPicker({required bool asCollaborators}) async {
    final list = _list;
    if (list == null) return;
    final alreadyIn =
        (asCollaborators ? _editors : _members).map((p) => p.id).toSet();
    final changed = await Navigator.push<bool>(
      context,
      ListMemberPickerPage.getRoute(
        list: list,
        asCollaborators: asCollaborators,
        alreadyIn: alreadyIn,
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _removeMember(ListPerson person) async {
    final list = _list;
    if (list == null) return;
    await _action(() => _repo.removeMember(list.id, person.id));
  }

  Future<void> _removeEditor(ListPerson person) async {
    final list = _list;
    if (list == null) return;
    await _action(() => _repo.setEditor(list.id, person.id, on: false));
  }

  Future<void> _delete() async {
    final list = _list;
    if (list == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete this list?', style: listTitleStyle(size: 18)),
        content: Text(
          'The list and its collaborators will be removed. The accounts on it are not affected.',
          style: listGreyStyle(size: 14, weight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: listTitleStyle(size: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: listTitleStyle(size: 15, color: TwitterColor.ceriseRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteList(list.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final me = SupabaseRepository.instance.uid;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: TwitterColor.mystic,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        title: Text(
          list?.name ?? 'List',
          style: listTitleStyle(size: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (list != null && list.canEdit)
            IconButton(
              tooltip: 'Edit list',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          if (list != null && list.isOwner)
            IconButton(
              tooltip: 'Delete list',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kListDividerColor),
        ),
      ),
      body: _loading && list == null
          ? const Center(child: SwiflyLoader())
          : list == null
              ? const Center(
                  child: ListEmptyState(
                    'This list is not available',
                    subTitle: 'It may be private, or it may have been deleted.',
                  ),
                )
              : RefreshIndicator(
                  color: AppColor.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _header(list),
                      _tabs(),
                      ...(_showMembers
                          ? _membersSection(list, me)
                          : _timelineSection()),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header(SwiflyList list) {
    final cover = list.coverUrl;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: cover == null
                  ? LinearGradient(
                      colors: list.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              image: cover == null
                  ? null
                  : DecorationImage(
                      image: customAdvanceNetworkImage(cover),
                      fit: BoxFit.cover,
                    ),
            ),
            child: cover == null
                ? Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Icon(list.iconData, color: Colors.white, size: 40),
                    ),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(list.name, style: listTitleStyle(size: 22)),
          ),
          if (list.ownerHandle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  PersonAvatar(url: list.ownerAvatar, radius: 11),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'by ${list.ownerName ?? ''} ${list.ownerHandle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: listGreyStyle(size: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (list.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                list.description,
                style: listGreyStyle(size: 15, weight: FontWeight.w600),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _stat(compactCount(list.memberCount), 'Members'),
                const SizedBox(width: 18),
                _stat(compactCount(list.followerCount), 'Followers'),
                const SizedBox(width: 18),
                ListPrivacyTag(isPrivate: list.isPrivate),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: _actions(list),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Row(
      children: [
        Text(value, style: listTitleStyle(size: 16)),
        const SizedBox(width: 4),
        Text(label, style: listGreyStyle(size: 14)),
      ],
    );
  }

  Widget _actions(SwiflyList list) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!list.canEdit)
          ListFollowButton(following: list.isFollowing, onTap: _toggleFollow),
        if (list.canEdit || list.isFollowing)
          OutlinedButton.icon(
            onPressed: _togglePin,
            icon: Icon(
              list.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 18,
            ),
            label: Text(
              list.isPinned ? 'Pinned' : 'Pin to my lists',
              style: listTitleStyle(size: 14, color: AppColor.primary),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColor.primary,
              side: const BorderSide(color: AppColor.primary, width: 1.5),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
      ],
    );
  }

  Widget _tabs() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _tab('Timeline', !_showMembers,
                () => setState(() => _showMembers = false)),
          ),
          Expanded(
            child: _tab('Members', _showMembers,
                () => setState(() => _showMembers = true)),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              style: listTitleStyle(
                  size: 15,
                  color: selected ? AppColor.primary : AppColor.darkGrey),
            ),
          ),
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            color: selected ? AppColor.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline: posts from the people on this list
  // ---------------------------------------------------------------------------

  List<Widget> _timelineSection() {
    if (_posts.isEmpty) {
      return [
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 10),
          child: ListEmptyState(
            'No posts yet',
            subTitle: 'Posts from the people on this list will show up here.',
          ),
        ),
      ];
    }
    return [
      for (final post in _posts)
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 10),
          child: Tweet(
            model: post,
            scaffoldKey: _scaffoldKey,
            trailing: TweetBottomSheet().tweetOptionIcon(
              context,
              model: post,
              type: TweetType.Tweet,
              scaffoldKey: _scaffoldKey,
            ),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Members and collaborators
  // ---------------------------------------------------------------------------

  List<Widget> _membersSection(SwiflyList list, String? me) {
    final items = <Widget>[
      _sectionHeader(
        'Members · ${compactCount(_members.length)}',
        action: list.canEdit
            ? _headerAction(
                'Add people', () => _openPicker(asCollaborators: false))
            : null,
      ),
    ];
    if (_members.isEmpty) {
      items.add(_hint('No one is on this list yet.'));
    }
    for (final person in _members) {
      final canRemove = list.canEdit || person.id == me;
      items.add(_personRow(
        person,
        trailing: canRemove ? _removeButton(() => _removeMember(person)) : null,
      ));
    }

    if (list.isOwner || _editors.isNotEmpty) {
      items.add(_sectionHeader(
        'Collaborators',
        action: list.isOwner
            ? _headerAction(
                'Invite', () => _openPicker(asCollaborators: true))
            : null,
      ));
      if (_editors.isEmpty) {
        items.add(_hint('Collaborators can add and remove people with you.'));
      }
      for (final person in _editors) {
        items.add(_personRow(
          person,
          trailing: list.isOwner ? _removeButton(() => _removeEditor(person)) : null,
        ));
      }
    }
    return items;
  }

  Widget _sectionHeader(String title, {Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: listTitleStyle(size: 17))),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _headerAction(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.person_add_alt_1, size: 18, color: AppColor.primary),
      label: Text(label, style: listTitleStyle(size: 14, color: AppColor.primary)),
    );
  }

  Widget _hint(String text) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(text, style: listGreyStyle(size: 14, weight: FontWeight.w600)),
    );
  }

  Widget _removeButton(VoidCallback onTap) {
    return IconButton(
      tooltip: 'Remove',
      icon: Icon(Icons.close, size: 20, color: AppColor.darkGrey),
      onPressed: onTap,
    );
  }

  Widget _personRow(ListPerson person, {Widget? trailing}) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        ProfilePage.getRoute(profileId: person.id),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            PersonAvatar(url: person.avatar, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listTitleStyle(size: 15),
                  ),
                  Text(
                    person.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listGreyStyle(size: 13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
