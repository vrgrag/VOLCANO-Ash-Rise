import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../relay/alert_center.dart';
import '../relay/locker.dart';
import '../relay/reach_probe.dart';
import '../wire/app_facade.dart';
import 'lava_button.dart';
import 'web_curtain.dart';

// ============================================================
// PUSH PROMPT CURTAIN — notification opt-in promo (gray flow)
// ============================================================
// Shown once before the WebView. Accept triggers the OS permission dialog;
// Skip arms a 3-day cooldown. Either way the user then continues to the
// content.
//
// Per the TZ note: NO SafeArea here and both buttons are horizontally
// centred (left:0/right:0 + a centred min-width Column) so the landscape
// camera-cutout inset cannot skew the layout. Accept sits above Skip on a
// shared padding rail, same width, aligned — never staggered.
// ============================================================

class PushPromptCurtain extends StatelessWidget {
  const PushPromptCurtain({
    super.key,
    required this.locker,
    required this.alertCenter,
    required this.reachProbe,
    required this.contentLink,
  });

  final Locker locker;
  final AlertCenter alertCenter;
  final ReachProbe reachProbe;
  final String contentLink;

  Future<void> _accept(BuildContext context) async {
    final bool granted = await alertCenter.askPermission();
    if (!granted) {
      await locker.writeInviteCooldown(_cooldownTarget());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    await locker.writeInviteCooldown(_cooldownTarget());
    if (context.mounted) _forward(context);
  }

  int _cooldownTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      AshFacade.pushInviteCooldown;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebCurtain(
          link: contentLink,
          locker: locker,
          alertCenter: alertCenter,
          reachProbe: reachProbe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.notificationsHorizontal
        : AppAssets.notificationsVertical;
    final double buttonWidth =
        landscape ? size.width * 0.42 : (size.width * 0.72).clamp(220.0, 400.0);

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LavaButton(
          label: 'Accept',
          icon: Icons.notifications_active_rounded,
          width: buttonWidth,
          compact: landscape,
          onTap: () => _accept(context),
        ),
        SizedBox(height: landscape ? 10 : 14),
        LavaGhostButton(
          label: 'Skip',
          width: buttonWidth,
          compact: landscape,
          onTap: () => _skip(context),
        ),
      ],
    );

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
                colors: [Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.07 : 0.06),
            child: Center(child: actions),
          ),
        ],
      ),
    );
  }
}
