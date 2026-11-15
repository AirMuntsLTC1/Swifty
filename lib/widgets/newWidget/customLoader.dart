import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

/// Full-screen loading overlay shown with the Swifly paper plane.
class CustomLoader {
  static CustomLoader? _customLoader;

  CustomLoader._createObject();

  factory CustomLoader() {
    _customLoader ??= CustomLoader._createObject();
    return _customLoader!;
  }

  OverlayState? _overlayState;
  OverlayEntry? _overlayEntry;

  void _buildLoader() {
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: buildLoader(context),
        );
      },
    );
  }

  void showLoader(context) {
    _overlayState = Overlay.of(context);
    _buildLoader();
    _overlayState!.insert(_overlayEntry!);
  }

  void hideLoader() {
    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (e) {
      debugPrint("Exception:: $e");
    }
  }

  Widget buildLoader(BuildContext context, {Color? backgroundColor}) {
    return CustomScreenLoader(
      height: 150,
      width: 150,
      backgroundColor: backgroundColor ?? Colors.black26,
    );
  }
}

class CustomScreenLoader extends StatelessWidget {
  final Color backgroundColor;
  final double height;
  final double width;

  const CustomScreenLoader({
    Key? key,
    this.backgroundColor = const Color(0x1F000000),
    this.height = 150,
    this.width = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Container(
        height: height,
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SwiflyLoader(size: 56),
      ),
    );
  }
}




