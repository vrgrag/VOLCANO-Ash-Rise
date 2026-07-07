import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// The volcanic crater target. Rendered from the ready-made concentric-ring
/// artwork so the visible rings line up exactly with the scoring tiers.
class LandingZone extends StatelessWidget {
  const LandingZone({super.key, required this.diameter, required this.pulse});

  final double diameter;

  /// 0..1 subtle breathing pulse to keep the zone feeling alive.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + pulse * 0.03;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Image.asset(AppAssets.landingZone, fit: BoxFit.contain),
      ),
    );
  }
}
