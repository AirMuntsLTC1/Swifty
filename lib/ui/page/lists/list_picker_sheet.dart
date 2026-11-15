import 'package:material_ui/material_ui.dart';

import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_join_button.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

/// Opened from the composer's list icon. Pops with the list you pick to post
/// to. Lists you can join are listed below, with Join or Request.
class ListPickerSheet extends StatefulWidget {
  const ListPickerSheet({super.key});

  @override
  State<ListPickerSheet> createState() => _ListPickerSheetState();
}

class _ListPickerSheetState extends State<ListPickerSheet> {
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
      // The repository has already shown the error.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final mine = (data?.yours ?? const <SwiflyList>[])
        .where((l) => l.canPostTo)
        .toList();
    final joinable = (data?.discover ?? const <SwiflyList>[])
        .where((l) => !l.canPostTo)
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Lists', style: listTitleStyle(size: 20)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Post to one of your lists, or join more.',
                style: listGreyStyle(size: 14, weight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: SwiflyLoader()),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        _label('Your lists'),
                        if (mine.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: Text(
                              'You are not on any lists yet. Join one below.',
                              style: listGreyStyle(size: 14, weight: FontWeight.w600),
                            ),
                          )
                        else
                          for (final list in mine) _mineRow(list),
                        _label('Join more lists'),
                        if (joinable.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: Text(
                              'No other lists to join right now.',
                              style: listGreyStyle(size: 14, weight: FontWeight.w600),
                            ),
                          )
                        else
                          for (final list in joinable) _joinRow(list),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(text, style: listTitleStyle(size: 16)),
    );
  }

  Widget _mineRow(SwiflyList list) {
    final role = list.isOwner
        ? 'Owner'
        : list.isEditor
            ? 'Collaborator'
            : 'Member';
    return InkWell(
      onTap: () => Navigator.pop(context, list),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            ListCover(list: list, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: listTitleStyle(size: 15)),
                  Text(role, style: listGreyStyle(size: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColor.darkGrey),
          ],
        ),
      ),
    );
  }

  Widget _joinRow(SwiflyList list) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          ListCover(list: list, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listTitleStyle(size: 15)),
                    ),
                    if (list.isPrivate) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline, size: 14, color: AppColor.darkGrey),
                    ],
                  ],
                ),
                Text(
                  '${compactCount(list.memberCount)} members',
                  style: listGreyStyle(size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ListJoinButton(list: list, onChanged: _load, compact: true),
        ],
      ),
    );
  }
}


