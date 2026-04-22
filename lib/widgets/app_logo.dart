import 'package:flutter/material.dart';

/// Reusable app logo widget that uses the asset image.
/// Falls back to the school icon if the image fails to load.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const AppLogo({
    super.key,
    this.size = 48,
    this.backgroundColor,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(size * 0.27))
            : null,
        shape: shape,
      ),
      clipBehavior: backgroundColor != null || borderRadius != null
          ? Clip.antiAlias
          : Clip.none,
      child: Image.asset(
        'assets/images/app logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.school_rounded,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
