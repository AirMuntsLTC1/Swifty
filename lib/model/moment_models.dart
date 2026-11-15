// lib/model/moment_models.dart
//
// Plain data classes for Moments. MomentsRepository builds these from
// Supabase rows. No Supabase imports here, so they are easy to test.
import 'package:flutter_twitter_clone/model/feedModel.dart';

/// Reactions a viewer can send. Stored as-is in story_reactions.emoji.
const List<String> kMomentEmojis = ['🔥', '😂', '❤️', '😮', '👏', '😢'];

/// Background colors for text Moments (ARGB, stored in stories.bg_color).
const List<int> kMomentBgColors = <int>[
  0xFF0084FF,
  0xFF7B2FF7,
  0xFFFF5E62,
  0xFF11998E,
  0xFF232526,
  0xFFF7971E,
];

/// The person who posted a Moment.
class MomentAuthor {
  const MomentAuthor({
    required this.id,
    required this.name,
    required this.handle,
    this.avatar,
  });

  final String id;
  final String name;
  final String handle;
  final String? avatar;

  factory MomentAuthor.fromRow(Map<String, dynamic> row) {
    final username = (row['username'] ?? '').toString();
    final avatarValue = (row['avatar_url'] ?? '').toString();
    return MomentAuthor(
      id: row['id'].toString(),
      name: (row['display_name'] ?? username).toString(),
      handle: username.startsWith('@') ? username : '@$username',
      avatar: avatarValue.isEmpty ? null : avatarValue,
    );
  }

  factory MomentAuthor.unknown(String id) =>
      MomentAuthor(id: id, name: 'Swifs user', handle: '@user');
}

/// One 24-hour story (a row in public.stories).
///
/// Text overlays are stored in `layers` as
/// `[{"kind": "text", "text": "..."}]`. Photo transforms come from
/// photo_scale / photo_dx / photo_dy / photo_rotation.
class MomentStory {
  const MomentStory({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.expiresAt,
    this.mediaUrl,
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.text,
    this.bgColor,
    this.place,
    this.photoScale = 1,
    this.photoDx = 0,
    this.photoDy = 0,
    this.photoRotation = 0,
  });

  final String id;
  final String authorId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? mediaUrl;

  /// 'image', 'video', or 'text' (no media).
  final String mediaType;

  /// Still image of a video story, shown until the video starts.
  final String? thumbnailUrl;
  final String? text;
  final int? bgColor;
  final String? place;
  final double photoScale;
  final double photoDx;
  final double photoDy;
  final double photoRotation;

  /// Maps a stories row. [resolveUrl] turns a stored path into a public URL.
  factory MomentStory.fromRow(
    Map<String, dynamic> row,
    String Function(String stored) resolveUrl,
  ) {
    final photo = (row['photo_path'] ?? '').toString();

    String? text;
    final layers = row['layers'];
    if (layers is List) {
      for (final layer in layers) {
        if (layer is Map && layer['kind'] == 'text') {
          final value = (layer['text'] ?? '').toString().trim();
          if (value.isNotEmpty) text = value;
          break;
        }
      }
    }

    final place = (row['place'] ?? '').toString();
    return MomentStory(
      id: row['id'].toString(),
      authorId: row['author_id'].toString(),
      createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
      expiresAt: DateTime.parse(row['expires_at'].toString()).toLocal(),
      mediaUrl: photo.isEmpty ? null : resolveUrl(photo),
      mediaType: (row['media_type'] ?? 'image').toString(),
      thumbnailUrl: (row['thumbnail_url'] ?? '').toString().isEmpty
          ? null
          : row['thumbnail_url'].toString(),
      text: text,
      bgColor: (row['bg_color'] as num?)?.toInt(),
      place: place.isEmpty ? null : place,
      photoScale: (row['photo_scale'] as num?)?.toDouble() ?? 1,
      photoDx: (row['photo_dx'] as num?)?.toDouble() ?? 0,
      photoDy: (row['photo_dy'] as num?)?.toDouble() ?? 0,
      photoRotation: (row['photo_rotation'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One avatar in the story ring: all live stories from one person.
class MomentRing {
  const MomentRing({
    required this.author,
    required this.stories,
    required this.hasUnseen,
    required this.isMine,
  });

  final MomentAuthor author;

  /// Oldest first, so the viewer plays them in the order they were posted.
  final List<MomentStory> stories;

  /// True when at least one story has not been viewed by you yet.
  final bool hasUnseen;
  final bool isMine;

  DateTime get latest => stories.last.createdAt;
}

/// A swipeable "live" deck of posts around one trending tag.
class MomentCapsule {
  const MomentCapsule({
    required this.tag,
    required this.uses,
    required this.posts,
  });

  final String tag;
  final int uses;
  final List<FeedModel> posts;
}

/// Counts shown to the author of a story.
class StoryStats {
  const StoryStats({required this.views, required this.reactions});

  final int views;
  final Map<String, int> reactions;

  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);
}




