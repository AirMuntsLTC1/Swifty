#!/usr/bin/env python3
"""Swifly: real ads in the home feed (one ad after every 6 posts).

Run from the project root (the folder with pubspec.yaml and lib/):
    python3 patch_ads.py

Safe to run twice. Shows nothing when there are no active campaigns.
"""
import pathlib
import sys

ROOT = pathlib.Path('.')
LIB = ROOT / 'lib'
FEED = LIB / 'ui' / 'page' / 'feed' / 'feedPage.dart'
AD_IMPORT = "import 'package:flutter_twitter_clone/widgets/ads/ad_slot.dart';\n"

LIST_START = "                    : SliverList(\n"
LIST_END = "                      )\n          ],\n"
NEW_LIST = """                    : SliverList(
                        delegate: SliverChildListDelegate(
                          _feedRows(context, list!),
                        ),
                      )
"""

BUILD_ANCHOR = ("  @override\n  Widget build(BuildContext context) {\n"
                "    var authState = Provider.of<AuthState>(context, listen: false);\n")
ROWS_METHOD = """  /// Feed rows: each post, with an ad slot after every kAdEvery posts.
  /// Slots with no active campaign render nothing.
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
      if ((i + 1) % kAdEvery == 0) {
        rows.add(AdSlot(key: ValueKey('feed-ad-$adSlot'), slotIndex: adSlot));
        adSlot++;
      }
    }
    return rows;
  }

"""


def fail(msg):
    sys.exit('ERROR: ' + msg)


def main():
    if not (ROOT / 'pubspec.yaml').exists() or not LIB.exists():
        fail('run from the project root (the folder with pubspec.yaml and lib/)')
    if not (LIB / 'widgets' / 'ads' / 'ad_slot.dart').exists():
        fail('lib/widgets/ads/ad_slot.dart is missing. Unzip the whole archive first.')
    if not FEED.exists():
        fail('lib/ui/page/feed/feedPage.dart not found')

    text = FEED.read_text(encoding='utf-8')
    if '_feedRows(' in text:
        print('Feed ads already applied.')
        return

    if text.count(LIST_START) != 1:
        fail('feed list block not found in feedPage.dart (file changed?)')
    start = text.index(LIST_START)
    end = text.index(LIST_END, start) + len("                      )\n")
    text = text[:start] + NEW_LIST + text[end:]

    if text.count(BUILD_ANCHOR) != 1:
        fail('build anchor not found in feedPage.dart')
    text = text.replace(BUILD_ANCHOR, ROWS_METHOD + BUILD_ANCHOR)

    if AD_IMPORT not in text:
        idx = text.index('\nimport ') + 1
        end_line = text.index('\n', idx) + 1
        text = text[:end_line] + AD_IMPORT + text[end_line:]

    FEED.write_text(text, encoding='utf-8')
    print('Feed: an ad slot is placed after every 6 posts.')
    print('Done. Run the SQL migration in Supabase, then add a real campaign.')


if __name__ == '__main__':
    main()
