// lib/ui/page/moments/moments_page.dart
//
// Moments screen, opened from the sidebar. Three zones:
//   1. Story ring row: your Moment (+) first, then people you follow.
//   2. Trending capsules: swipeable decks built from trending tags.
//   3. Explore grid: For you (newest) or Trending (most liked).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/moment_models.dart';
import 'package:flutter_twitter_clone/supabase/supabase_moments_repository.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';
import 'package:flutter_twitter_clone/ui/page/moments/capsule_page.dart';
import 'package:flutter_twitter_clone/ui/page/moments/moments_widgets.dart';
import 'package:flutter_twitter_clone/ui/page/moments/story_composer_page.dart';
import 'package:flutter_twitter_clone/ui/page/moments/story_viewer_page.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  static Route<dynamic> getRoute() {
    return CustomRoute(
      builder: (_) => const MomentsPage(),
      settings: const RouteSettings(name: 'MomentsPage'),
    );
  }

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final MomentsRepository _repo = MomentsRepository.instance;

  List<MomentRing> _rings = const [];
  List<MomentCapsule> _capsules = const [];
  List<FeedModel> _explore = const [];
  String? _myAvatar;
  bool _trending = false;
  bool _loading = true;
  bool _exploreLoading = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Any story change (new, expired, deleted) refreshes the ring row.
    _channel = _repo.subscribeStories('moments-stories', () {
      if (mounted) _loadRings();
    });
    _loadAll();
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _repo.closeChannel(channel);
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadMe(),
      _loadRings(),
      _loadCapsules(),
      _loadExplore(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMe() async {
    final me = SupabaseRepository.instance.uid;
    if (me == null) return;
    try {
      final user = await SupabaseRepository.instance.fetchUser(me);
      if (mounted) setState(() => _myAvatar = user?.profilePic);
    } catch (_) {
      // Shown by the repository. The bubble just uses the default avatar.
    }
  }

  Future<void> _loadRings() async {
    try {
      final rings = await _repo.fetchRings();
      if (mounted) setState(() => _rings = rings);
    } catch (_) {}
  }

  Future<void> _loadCapsules() async {
    try {
      final capsules = await _repo.fetchCapsules();
      if (mounted) setState(() => _capsules = capsules);
    } catch (_) {}
  }

  Future<void> _loadExplore() async {
    if (mounted) setState(() => _exploreLoading = true);
    try {
      final posts = await _repo.fetchExplore(trending: _trending);
      if (mounted) setState(() => _explore = posts);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _exploreLoading = false);
    }
  }

  void _setTrending(bool value) {
    if (_trending == value) return;
    setState(() => _trending = value);
    _loadExplore();
  }

  Future<void> _openViewer(int ringIndex) async {
    await Navigator.push(
      context,
      StoryViewerPage.getRoute(rings: _rings, initialRing: ringIndex),
    );
    if (mounted) _loadRings();
  }

  Future<void> _openComposer() async {
    final posted = await Navigator.push<bool>(
      context,
      StoryComposerPage.getRoute(),
    );
    if (posted == true && mounted) _loadRings();
  }

  Future<void> _openCapsule(MomentCapsule capsule) async {
    await Navigator.push(
      context,
      CapsulePage.getRoute(
        title: '#${capsule.tag}',
        posts: capsule.posts,
        live: true,
      ),
    );
  }

  Future<void> _openExplore(int index) async {
    await Navigator.push(
      context,
      CapsulePage.getRoute(
        title: _trending ? 'Trending' : 'For you',
        posts: _explore,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = _rings.where((r) => r.isMine).toList();
    final MomentRing? mineRing = mine.isEmpty ? null : mine.first;
    final others = _rings.where((r) => !r.isMine).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Moments', style: momentTitle(size: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kMomentBorder),
        ),
      ),
      body: _loading && _rings.isEmpty && _explore.isEmpty
          ? const Center(child: SwiflyLoader())
          : RefreshIndicator(
              color: AppColor.primary,
              onRefresh: _loadAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _storiesRow(mineRing, others)),
                  SliverToBoxAdapter(child: _capsulesBlock()),
                  SliverToBoxAdapter(child: _exploreHeader()),
                  _exploreSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  // Zone 1: story ring row.
  Widget _storiesRow(MomentRing? mine, List<MomentRing> others) {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        children: [
          StoryRing(
            label: 'Your Moment',
            avatar: mine?.author.avatar ?? _myAvatar,
            highlighted: mine != null && mine.hasUnseen,
            onTap: mine == null
                ? _openComposer
                : () => _openViewer(_rings.indexOf(mine)),
            badge: _addBadge(),
          ),
          for (final ring in others)
            StoryRing(
              label: ring.author.name,
              avatar: ring.author.avatar,
              highlighted: ring.hasUnseen,
              onTap: () => _openViewer(_rings.indexOf(ring)),
            ),
        ],
      ),
    );
  }

  Widget _addBadge() {
    return GestureDetector(
      onTap: _openComposer,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColor.primary,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(LucideIcons.plus, size: 13, color: Colors.white),
      ),
    );
  }

  // Zone 2: trending capsules.
  Widget _capsulesBlock() {
    if (_capsules.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const MomentLiveBadge(),
              const SizedBox(width: 8),
              Text('Trending capsules', style: momentTitle(size: 16)),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _capsules.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => CapsuleCard(
              capsule: _capsules[i],
              onTap: () => _openCapsule(_capsules[i]),
            ),
          ),
        ),
      ],
    );
  }

  // Zone 3: explore grid.
  Widget _exploreHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          MomentFilterPill(
            label: 'For you',
            selected: !_trending,
            onTap: () => _setTrending(false),
          ),
          const SizedBox(width: 8),
          MomentFilterPill(
            label: 'Trending',
            selected: _trending,
            onTap: () => _setTrending(true),
          ),
          const Spacer(),
          if (_exploreLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _exploreSliver() {
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
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
        children: [
          for (var i = 0; i < _explore.length; i++)
            MomentTile(post: _explore[i], onTap: () => _openExplore(i)),
        ],
      ),
    );
  }
}


