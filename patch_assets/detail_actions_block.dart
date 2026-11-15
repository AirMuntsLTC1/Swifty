  Widget _actions(SwiflyList list) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!list.canEdit)
          ListJoinButton(
            list: list,
            onChanged: () {
              _changed = true;
              _load();
            },
          ),
        if (!list.canEdit && (!list.isPrivate || list.isMember))
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

  Widget _privateNotice() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 10),
      child: ListEmptyState(
        'This list is private',
        subTitle: 'Request to join to see its posts and members.',
      ),
    );
  }

  List<Widget> _requestItems(SwiflyList list) {
    if (_requests.isEmpty) return [];
    return [
      _sectionHeader('Join requests · ${compactCount(_requests.length)}'),
      for (final request in _requests) _requestRow(list, request),
    ];
  }

  Widget _requestRow(SwiflyList list, ListJoinRequest request) {
    final person = request.person;
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
          TextButton(
            onPressed: () => _respond(list, request, accept: false),
            child: Text('Decline', style: listGreyStyle(size: 14)),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _respond(list, request, accept: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Accept',
                style: listTitleStyle(size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    SwiflyList list,
    ListJoinRequest request, {
    required bool accept,
  }) async {
    try {
      await _repo.respondJoinRequest(list.id, request.userId, accept: accept);
    } catch (_) {
      // The repository has already shown the error.
    }
    _changed = true;
    await _load();
  }

