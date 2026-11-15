import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

/// Search for people and add them to a list, or invite them as collaborators.
/// Pops with true if anything was added.
class ListMemberPickerPage extends StatefulWidget {
  const ListMemberPickerPage({
    super.key,
    required this.list,
    required this.asCollaborators,
    required this.alreadyIn,
  });

  final SwiflyList list;
  final bool asCollaborators;
  final Set<String> alreadyIn;

  static Route<bool> getRoute({
    required SwiflyList list,
    required bool asCollaborators,
    required Set<String> alreadyIn,
  }) {
    return CustomRoute<bool>(
      builder: (_) => ListMemberPickerPage(
        list: list,
        asCollaborators: asCollaborators,
        alreadyIn: alreadyIn,
      ),
      settings: const RouteSettings(name: 'ListMemberPickerPage'),
    );
  }

  @override
  State<ListMemberPickerPage> createState() => _ListMemberPickerPageState();
}

class _ListMemberPickerPageState extends State<ListMemberPickerPage> {
  final _searchController = TextEditingController();
  final _repo = SwiflyListsRepository.instance;
  late final Set<String> _added = {...widget.alreadyIn};
  List<ListPerson> _results = [];
  bool _searching = false;
  bool _changed = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _searching = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _searching = true);
    try {
      final rows = await _repo.searchPeople(query);
      if (mounted) {
        setState(() => _results =
            rows.where((p) => p.id != widget.list.ownerId).toList());
      }
    } catch (_) {
      // The repository has already shown the error.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(ListPerson person) async {
    try {
      if (widget.asCollaborators) {
        await _repo.setEditor(widget.list.id, person.id, on: true);
      } else {
        await _repo.addMember(widget.list.id, person.id);
      }
      if (mounted) {
        setState(() {
          _added.add(person.id);
          _changed = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.asCollaborators ? 'Invite collaborators' : 'Add people';
    return Scaffold(
      backgroundColor: TwitterColor.mystic,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        title: Text(title, style: listTitleStyle(size: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kListDividerColor),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              style: listTitleStyle(size: 15),
              decoration: InputDecoration(
                hintText: 'Search by name or @username',
                hintStyle: listGreyStyle(size: 15, weight: FontWeight.w600),
                prefixIcon: Icon(Icons.search, color: AppColor.darkGrey),
                filled: true,
                fillColor: const Color(0xffF5F8FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_searching) {
      return const Center(child: SwiflyLoader());
    }
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Type a name or username to find people.',
            textAlign: TextAlign.center,
            style: listGreyStyle(size: 15, weight: FontWeight.w600),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const ListEmptyState(
        'No people found',
        subTitle: 'Try a different name or username.',
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _row(_results[i]),
    );
  }

  Widget _row(ListPerson person) {
    final added = _added.contains(person.id);
    return Container(
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
          const SizedBox(width: 10),
          if (added)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: TwitterColor.mystic,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.asCollaborators ? 'Invited' : 'Added',
                style: listGreyStyle(size: 13),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _add(person),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.asCollaborators ? 'Invite' : 'Add',
                  style: listTitleStyle(size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
