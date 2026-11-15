import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/page/lists/listDetailPage.dart';
import 'package:flutter_twitter_clone/ui/page/lists/listFormPage.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_join_button.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  static Route<dynamic> getRoute() {
    return CustomRoute(
      builder: (_) => const ListsPage(),
      settings: const RouteSettings(name: 'ListsPage'),
    );
  }

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final _repo = SwiflyListsRepository.instance;
  ListsOverview? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchOverview();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      // The repository has already shown the error to the user.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs an action and refreshes; a failed action is already shown to the user.
  Future<void> _action(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {}
    if (mounted) _load();
  }

  Future<void> _open(SwiflyList list) async {
    await Navigator.push(context, ListDetailPage.getRoute(list.id));
    if (mounted) _load();
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(context, ListFormPage.getRoute());
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: TwitterColor.mystic,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Lists', style: listTitleStyle(size: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kListDividerColor),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColor.primary,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New list', style: listTitleStyle(size: 15, color: Colors.white)),
      ),
      body: _loading && data == null
          ? const Center(child: SwiflyLoader())
          : RefreshIndicator(
              color: AppColor.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                children: [
                  _section('Pinned', _pinnedRow(data?.pinned ?? const [])),
                  _section('Discover popular lists', _discoverColumn(data?.discover ?? const [])),
                  _section('Your lists', _yoursColumn(data?.yours ?? const [])),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(title, style: listTitleStyle(size: 18)),
          ),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pinnedRow(List<SwiflyList> lists) {
    if (lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          'Follow a list, then pin it here for one-tap access.',
          style: listGreyStyle(size: 14, weight: FontWeight.w600),
        ),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _pinnedCard(lists[i]),
      ),
    );
  }

  Widget _pinnedCard(SwiflyList list) {
    final cover = list.coverUrl;
    return GestureDetector(
      onTap: () => _open(list),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 128,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: list.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              else
                Image(image: customAdvanceNetworkImage(cover), fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xB3000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(list.iconData, color: Colors.white, size: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          list.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: listTitleStyle(size: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${compactCount(list.memberCount)} members · '
                          '${compactCount(list.followerCount)} followers',
                          style: listTitleStyle(size: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discoverColumn(List<SwiflyList> lists) {
    if (lists.isEmpty) {
      return const ListEmptyState(
        'No popular lists yet',
        subTitle: 'Public lists from other people will show up here.',
      );
    }
    return Column(
      children: [for (final list in lists) _discoverRow(list)],
    );
  }

  Widget _discoverRow(SwiflyList list) {
    final owner = list.ownerHandle;
    return InkWell(
      onTap: () => _open(list),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            ListCover(list: list),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listTitleStyle(size: 16),
                  ),
                  if (list.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        list.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: listGreyStyle(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${owner == null ? '' : 'by $owner · '}'
                    '${compactCount(list.memberCount)} members · '
                    '${compactCount(list.followerCount)} followers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listGreyStyle(size: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ListJoinButton(list: list, onChanged: _load, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _yoursColumn(List<SwiflyList> lists) {
    if (lists.isEmpty) {
      return const ListEmptyState(
        'No lists yet',
        subTitle: 'Create a list, or follow one, and it will show up here.',
      );
    }
    return Column(
      children: [for (final list in lists) _yourRow(list)],
    );
  }

  Widget _yourRow(SwiflyList list) {
    final role = list.isOwner
        ? 'Owner'
        : list.isEditor
            ? 'Collaborator'
            : list.isMember
                ? 'Member'
                : 'Following';
    return InkWell(
      onTap: () => _open(list),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            ListCover(list: list, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listTitleStyle(size: 16),
                        ),
                      ),
                      if (list.isPrivate) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline, size: 15, color: AppColor.darkGrey),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$role · ${compactCount(list.memberCount)} members · '
                    '${compactCount(list.followerCount)} followers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listGreyStyle(size: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: list.isPinned ? 'Unpin' : 'Pin',
              onPressed: () => _action(
                  () => _repo.setPin(list.id, pinned: !list.isPinned)),
              icon: Icon(
                list.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: list.isPinned ? AppColor.primary : AppColor.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




