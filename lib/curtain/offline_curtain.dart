import 'package:flutter/material.dart';

import '../bridge/insight.dart';
import '../core/constants.dart';
import 'lava_button.dart';

// ============================================================
// OFFLINE CURTAIN — no-connection screen (gray flow)
// ============================================================
// Orientation-aware no-wifi artwork with a single Retry button.
//
// Per the TZ note: NO SafeArea on this screen and the button is placed
// horizontally dead-centre (left:0/right:0 + Center) so the landscape
// camera-cutout inset can never push it off-axis. Width is capped so it
// never goes full-bleed (gray_part_pitfalls.md §18).
// ============================================================

class OfflineCurtain extends StatefulWidget {
  const OfflineCurtain({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineCurtain> createState() => _OfflineCurtainState();
}

class _OfflineCurtainState extends State<OfflineCurtain> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('offline');
  }

  Future<void> _retry() async {
    if (_busy) return;
    Insight.event('offline_retry');
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg =
        landscape ? AppAssets.noWifiHorizontal : AppAssets.noWifiVertical;
    final double buttonWidth =
        landscape ? size.width * 0.35 : (size.width * 0.72).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.09 : 0.08),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.emberOrange),
                      ),
                    )
                  : LavaButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      width: buttonWidth,
                      compact: landscape,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
