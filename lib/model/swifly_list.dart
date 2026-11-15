import 'package:flutter/material.dart';

/// Icons a list can use. The key is what is stored in lists.icon.
class SwiflyListIcons {
  SwiflyListIcons._();

  static const Map<String, IconData> byKey = {
    'list': Icons.list_alt,
    'news': Icons.newspaper,
    'code': Icons.code,
    'music': Icons.music_note,
    'camera': Icons.camera_alt,
    'heart': Icons.favorite,
    'star': Icons.star,
    'globe': Icons.public,
    'briefcase': Icons.work,
    'book': Icons.menu_book,
    'game': Icons.sports_esports,
    'trending': Icons.trending_up,
  };

  static IconData of(String key) => byKey[key] ?? Icons.list_alt;
}

/// Gradients used for a list that has no cover photo.
const List<List<Color>> kListGradients = [
  [Color(0xff0084FF), Color(0xff66B3FF)],
  [Color(0xff7B2FF7), Color(0xffB388FF)],
  [Color(0xffFF6B6B), Color(0xffFFA94D)],
  [Color(0xff11998E), Color(0xff38EF7D)],
  [Color(0xff14171A), Color(0xff44505A)],
  [Color(0xffE0245E), Color(0xffFF8FAB)],
];

/// A row from the lists table, plus what the signed-in user has to do with it.
class SwiflyList {
  SwiflyList({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.icon,
    required this.coverUrl,
    required this.isPrivate,
    required this.memberCount,
    required this.followerCount,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  String name;
  String description;
  String icon;
  String? coverUrl;
  bool isPrivate;
  int memberCount;
  int followerCount;
  final String createdAt;

  String? ownerName;
  String? ownerHandle;
  String? ownerAvatar;

  /// Relative to the signed-in user.
  bool isOwner = false;
  bool isEditor = false;
  bool isFollowing = false;
  bool isPinned = false;

  bool get canEdit => isOwner || isEditor;

  IconData get iconData => SwiflyListIcons.of(icon);

  List<Color> get gradient {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return kListGradients[seed % kListGradients.length];
  }

  factory SwiflyList.fromRow(Map<String, dynamic> row) {
    final cover = (row['cover_url'] ?? '').toString();
    return SwiflyList(
      id: row['id'].toString(),
      ownerId: row['owner_id'].toString(),
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      icon: (row['icon'] ?? 'list').toString(),
      coverUrl: cover.isEmpty ? null : cover,
      isPrivate: row['is_private'] == true,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      createdAt: (row['created_at'] ?? '').toString(),
    );
  }
}
