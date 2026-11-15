import 'package:material_ui/material_ui.dart';

import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// Join, Request, Requested or Joined, depending on the list and your status.
/// Public lists join at once; private lists send a request to the admins.
class ListJoinButton extends StatelessWidget {
  const ListJoinButton({
    super.key,
    required this.list,
    required this.onChanged,
    this.compact = false,
  });

  final SwiflyList list;
  final VoidCallback onChanged;
  final bool compact;

  Future<void> _tap() async {
    final repo = SwiflyListsRepository.instance;
    try {
      if (list.isMember) {
        await repo.leaveList(list.id);
      } else if (list.hasPendingRequest) {
        await repo.cancelJoinRequest(list.id);
      } else {
        await repo.joinList(list.id);
      }
    } catch (_) {
      // The repository has already shown the error.
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final String label;
    final bool filled;
    if (list.isMember) {
      label = 'Joined';
      filled = false;
    } else if (list.hasPendingRequest) {
      label = 'Requested';
      filled = false;
    } else if (list.isPrivate) {
      label = compact ? 'Request' : 'Request to join';
      filled = true;
    } else {
      label = compact ? 'Join' : 'Join list';
      filled = true;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColor.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColor.primary, width: 1.5),
        ),
        child: Text(
          label,
          style: listTitleStyle(
              size: 14, color: filled ? Colors.white : AppColor.primary),
        ),
      ),
    );
  }
}


