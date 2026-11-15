#!/usr/bin/env python3
"""Swifly: feed ads, Moments ads and story fixes.

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_moments.py

1. Feed: adds the ad slots to the home feed if they are missing (this was
   never applied), with the first ad after 3 posts, then every 6.
2. Moments: a full-width ad after every 6 Moments tiles.
3. Checks that the new files are in place.

Safe to run twice.
"""
import pathlib
import sys

ROOT = pathlib.Path('.')
LIB = ROOT / 'lib'
FEED = LIB / 'ui' / 'page' / 'feed' / 'feedPage.dart'
MOMENTS = LIB / 'ui' / 'page' / 'moments' / 'moments_page.dart'
FEED_AD_IMPORT = "import 'package:flutter_twitter_clone/widgets/ads/ad_slot.dart';\n"

REQUIRED = [
    LIB / 'ui' / 'page' / 'moments' / 'story_video.dart',
    LIB / 'ui' / 'page' / 'moments' / 'story_viewer_page.dart',
    LIB / 'supabase' / 'supabase_story_engagement.dart',
    LIB / 'widgets' / 'ads' / 'ad_slot.dart',
]

# ---- Feed -------------------------------------------------------------------
FEED_LIST_START = "                    : SliverList(\n"
FEED_LIST_END = "                      )\n          ],\n"
FEED_NEW_LIST = """                    : SliverList(
                        delegate: SliverChildListDelegate(
                          _feedRows(context, list!),
                        ),
                      )
"""
FEED_BUILD_ANCHOR = ("  @override\n  Widget build(BuildContext context) {\n"
                     "    var authState = Provider.of<AuthState>(context, listen: false);\n")
FEED_ROWS_METHOD = """  /// Feed rows: each post, with an ad slot after posts 3, 9, 15, and so on.
  /// Slots with no active campaign and no AdMob render nothing.
  List<Widget> _feedRows(BuildContext context, List<FeedModel> list) {
    final rows = <Widget>[];
    var adSlot = 0;
    for (var i = 0; i < list.length; i++) {
      final model = list[i];
      rows.add(
        Container(
          color: Colors.white,
          child: Tweet(
            model: model,
            trailing: TweetBottomSheet().tweetOptionIcon(
              context,
              model: model,
              type: TweetType.Tweet,
              scaffoldKey: scaffoldKey,
            ),
            scaffoldKey: scaffoldKey,
          ),
        ),
      );
      if ((i + 1) >= 3 && ((i + 1) - 3) % kAdEvery == 0) {
        rows.add(AdSlot(key: ValueKey('feed-ad-$adSlot'), slotIndex: adSlot));
        adSlot++;
      }
    }
    return rows;
  }

"""

# ---- Moments ----------------------------------------------------------------
EXPLORE_METHOD = """  Widget _exploreSliver() {
    if (_explore.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No Moments yet. Be the first to post one.',
              textAlign: TextAlign.center,
              style: momentMuted(),
            ),
          ),
        ),
      );
    }
    // After every kAdEvery tiles, a full-width ad: your campaigns first,
    // then Google AdMob. Nothing is shown when neither is available.
    final groups = <Widget>[];
    for (var start = 0; start < _explore.length; start += kAdEvery) {
      final end = start + kAdEvery > _explore.length
          ? _explore.length
          : start + kAdEvery;
      groups.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              for (var i = start; i < end; i++)
                MomentTile(post: _explore[i], onTap: () => _openExplore(i)),
            ],
          ),
        ),
      );
      groups.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: AdSlot(
              key: ValueKey('moments-ad-${start ~/ kAdEvery}'),
              slotIndex: start ~/ kAdEvery,
            ),
          ),
        ),
      );
    }
    return SliverMainAxisGroup(slivers: groups);
  }
"""


def fail(msg):
    sys.exit('ERROR: ' + msg)


def add_import(text, line):
    if line in text:
        return text
    idx = text.index('\nimport ') + 1
    end = text.index('\n', idx) + 1
    return text[:end] + line + text[end:]


def patch_feed():
    text = FEED.read_text(encoding='utf-8')
    if '_feedRows(' in text:
        if "((i + 1) - 3) % kAdEvery" not in text:
            fail('feed has ad slots with an older rule. Send feedPage.dart so I can fix it.')
        print('  feed ads already in place (first after 3 posts, then every 6)')
        return
    if text.count(FEED_LIST_START) != 1:
        fail('feed list block not found in feedPage.dart (file changed?)')
    start = text.index(FEED_LIST_START)
    end = text.index(FEED_LIST_END, start) + len("                      )\n")
    text = text[:start] + FEED_NEW_LIST + text[end:]
    if text.count(FEED_BUILD_ANCHOR) != 1:
        fail('build anchor not found in feedPage.dart')
    text = text.replace(FEED_BUILD_ANCHOR, FEED_ROWS_METHOD + FEED_BUILD_ANCHOR)
    text = add_import(text, FEED_AD_IMPORT)
    FEED.write_text(text, encoding='utf-8')
    print('  feed ads added: first after 3 posts, then every 6')


def patch_moments_page():
    text = MOMENTS.read_text(encoding='utf-8')
    if 'moments-ad-' in text:
        print('  Moments ads already added')
        return
    start = text.find('  Widget _exploreSliver() {')
    if start == -1:
        fail('_exploreSliver not found in moments_page.dart')
    end = text.find('\n  }\n}', start)
    if end == -1:
        fail('end of _exploreSliver not found in moments_page.dart')
    end += len('\n  }\n')
    text = text[:start] + EXPLORE_METHOD + text[end:]
    text = add_import(text, FEED_AD_IMPORT)
    MOMENTS.write_text(text, encoding='utf-8')
    print('  Moments grid: a full-width ad after every 6 tiles')


def check_required():
    missing = [str(p) for p in REQUIRED if not p.exists()]
    if missing:
        fail('missing files, unzip the whole archive first: ' + ', '.join(missing))


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not LIB.exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    check_required()
    print('1/2 Feed ads')
    patch_feed()
    print('2/2 Moments ads')
    patch_moments_page()
    print('Done. Run the SQL migration in Supabase, then build.')


if __name__ == '__main__':
    main()
