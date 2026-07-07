import 'package:flutter/material.dart';

/// A single falling volcanic object. Purely presentational — position is
/// driven entirely by the parent via [centerY].
class FallingObject extends StatelessWidget {
  const FallingObject({
    super.key,
    required this.asset,
    required this.size,
    required this.centerY,
    required this.rotation,
    this.isGolden = false,
  });

  final String asset;
  final double size;
  final double centerY;
  final double rotation;
  final bool isGolden;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: centerY - size / 2,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: size,
            height: size,
            decoration: isGolden
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                        blurRadius: 26,
                        spreadRadius: 4,
                      ),
                    ],
                  )
                : null,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
