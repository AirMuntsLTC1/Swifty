import 'package:flutter/material.dart';

/// Swifly brand colors. The logo and loader are drawn in code (no image files).
class SwiflyBrand {
  SwiflyBrand._();
  static const Color blue = Color(0xFF0084FF);
  static const Color blueLight = Color(0xFF66B3FF);
  static const Color white = Color(0xFFFFFFFF);
}

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

/// Paper plane, drawn in a 108 x 108 design space and scaled to fit.
class SwiflyPlanePainter extends CustomPainter {
  const SwiflyPlanePainter({
    this.color = SwiflyBrand.blue,
    this.shade = SwiflyBrand.blueLight,
  });

  final Color color;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 108.0;
    canvas.save();
    canvas.translate(
      (size.width - 108 * scale) / 2,
      (size.height - 108 * scale) / 2,
    );
    canvas.scale(scale);

    Path triangle(List<Offset> p) => Path()
      ..moveTo(p[0].dx, p[0].dy)
      ..lineTo(p[1].dx, p[1].dy)
      ..lineTo(p[2].dx, p[2].dy)
      ..close();

    canvas.drawPath(
      triangle(const [Offset(21.1, 50.8), Offset(87, 31), Offset(35.7, 56.8)]),
      _fill(color),
    );
    canvas.drawPath(
      triangle(const [Offset(87, 31), Offset(69.8, 77.1), Offset(46.5, 62)]),
      _fill(color),
    );
    canvas.drawPath(
      triangle(const [Offset(35.7, 56.8), Offset(46.5, 62), Offset(41.3, 77.1)]),
      _fill(shade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SwiflyPlanePainter old) =>
      old.color != color || old.shade != shade;
}

/// The Swifly logo: a blue paper plane.
class SwiflyLogo extends StatelessWidget {
  const SwiflyLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: SwiflyPlanePainter()),
    );
  }
}

/// Loading indicator: the paper plane gently floats and pulses.
class SwiflyLoader extends StatefulWidget {
  const SwiflyLoader({super.key, this.size = 36});

  final double size;

  @override
  State<SwiflyLoader> createState() => _SwiflyLoaderState();
}

class _SwiflyLoaderState extends State<SwiflyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: SwiflyLogo(size: widget.size),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Opacity(
          opacity: 0.45 + 0.55 * t,
          child: Transform.translate(
            offset: Offset(0, -3 + 6 * t),
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
        );
      },
    );
  }
}
