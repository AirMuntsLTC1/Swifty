// lib/widgets/verified_badge.dart
//
// Animated blue verified badge. Shown next to a name everywhere the app shows
// a user. Tap it to open a short slide show explaining verification.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Color kVerifiedBlue = Color(0xFF1D9BF0);

class VerifiedBadge extends StatefulWidget {
  const VerifiedBadge({super.key, this.size = 14, this.onTap});

  final double size;

  /// Null means "open the verification slide show".
  final VoidCallback? onTap;

  @override
  State<VerifiedBadge> createState() => _VerifiedBadgeState();
}

class _VerifiedBadgeState extends State<VerifiedBadge>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    return Semantics(
      label: 'Verified account',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap ?? () => VerifiedBadgeInfo.show(context),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop, _pulse]),
          builder: (context, _) {
            final double pop = Curves.elasticOut.transform(_pop.value);
            final double beat = Curves.easeInOut.transform(_pulse.value);
            return Transform.scale(
              scale: pop * (1 + 0.06 * beat),
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  color: kVerifiedBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kVerifiedBlue.withOpacity(0.15 + 0.25 * beat),
                      blurRadius: s * 0.6,
                      spreadRadius: s * 0.05,
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.check,
                  size: s * 0.7,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void _ignore() {}

/// Opens the verification slide show as a bottom sheet.
class VerifiedBadgeInfo {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _VerifiedSlideShow(),
    );
  }
}

class _SlideData {
  const _SlideData(this.title, this.body);
  final String title;
  final String body;
}

class _VerifiedSlideShow extends StatefulWidget {
  const _VerifiedSlideShow();

  @override
  State<_VerifiedSlideShow> createState() => _VerifiedSlideShowState();
}

class _VerifiedSlideShowState extends State<_VerifiedSlideShow> {
  final PageController _pages = PageController();
  int _index = 0;

  static const List<_SlideData> _slides = [
    _SlideData(
      'Verified account',
      'The blue badge means the Swifly team has confirmed this account is authentic.',
    ),
    _SlideData(
      'Why it matters',
      'Verification helps people know they are talking to the real person or brand, not an impostor.',
    ),
    _SlideData(
      'Shown everywhere',
      'The badge appears on posts, comments, chats, search results, lists and profiles.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      Navigator.of(context).pop();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _index == _slides.length - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VerifiedBadge(size: 64, onTap: _ignore),
                    const SizedBox(height: 20),
                    Text(
                      _slides[i].title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _slides[i].body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.black54, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? kVerifiedBlue : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kVerifiedBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _next,
                child: Text(
                  last ? 'Got it' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
