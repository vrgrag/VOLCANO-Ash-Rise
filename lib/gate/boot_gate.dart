import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/storage/stats_repository.dart';
import '../curtain/offline_curtain.dart';
import '../curtain/push_prompt_curtain.dart';
import '../curtain/web_curtain.dart';
import '../menu/main_menu_screen.dart';
import '../model/channel_mode.dart';
import '../model/verdict.dart';
import '../relay/alert_center.dart';
import '../relay/locker.dart';
import '../relay/reach_probe.dart';
import '../relay/signal_relay.dart';
import '../relay/verdict_channel.dart';

// ============================================================
// BOOT GATE — loading screen + remote/local decision engine
// ============================================================
// The single startup screen. Shows the loading artwork with a progress
// bar and animated "Loading..." caption while it resolves attribution and
// queries the config gate, then routes to either the WebView (gray) or
// the native game (white).
//
// Implements the state machine in .cursor/rules/android_gray_guide.md
// §"Gray Flow State Machine". Read it before altering any branch.
//
// [FIRST-LAUNCH UX INVARIANT] On the very FIRST launch while offline
// (OneLink install, Wi-Fi off) _firstRun() short-circuits into
// _toOffline() BEFORE attribution ignites, so the No-Wi-Fi curtain is the
// first pixel. Retry rebuilds a fresh BootGate and re-runs the pipeline.
// AppMode stays `fresh` on a network failure — only a successful
// {ok:false} commits `local`.
// ============================================================

class BootGate extends StatefulWidget {
  const BootGate({
    super.key,
    required this.locker,
    required this.reachProbe,
    required this.signalRelay,
    required this.verdictChannel,
    required this.alertCenter,
  });

  final Locker locker;
  final ReachProbe reachProbe;
  final SignalRelay signalRelay;
  final VerdictChannel verdictChannel;
  final AlertCenter alertCenter;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _routed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.alertCenter.onTokenRotated = _repostToken;
    _drive();
  }

  @override
  void dispose() {
    widget.alertCenter.onTokenRotated = null;
    _dots.dispose();
    super.dispose();
  }

  void _lift(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _drive() async {
    await widget.alertCenter.boot();
    _lift(0.2);

    switch (widget.locker.readMode()) {
      case ChannelMode.local:
        await _goLocal(initialLift: 0.4);
        break;
      case ChannelMode.remote:
        await _resumeRemote();
        break;
      case ChannelMode.fresh:
        await _firstRun();
        break;
    }
  }

  Future<void> _firstRun() async {
    if (!await widget.reachProbe.isReachable()) {
      _toOffline();
      return;
    }
    _lift(0.4);

    await widget.signalRelay.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.signalRelay.awaitInstallData(),
      widget.signalRelay.awaitDeepLink(),
    ]);
    _lift(0.7);

    final Verdict verdict = await _ask();
    if (verdict.allowed && verdict.hasLink) {
      await widget.locker.writeMode(ChannelMode.remote);
      _lift(1.0);
      await _settle();
      _toRemote(verdict.link!);
    } else {
      // Successful {ok:false} (or hard denial) commits local permanently.
      await widget.locker.writeMode(ChannelMode.local);
      await _goLocal(initialLift: 0.85);
    }
  }

  Future<void> _resumeRemote() async {
    if (!await widget.reachProbe.isReachable()) {
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.4);

    // A pending push link (cold-start tap) wins over everything.
    final String? pending = await widget.locker.takePendingLink();
    if (pending != null) {
      _lift(1.0);
      await _settle();
      _toRemote(pending, skipInvite: true);
      return;
    }

    final String? cached = await widget.locker.readCachedLink();

    // If the cached link is still valid, skip the network entirely.
    if (cached != null && !widget.locker.isLinkStale()) {
      _lift(1.0);
      await _settle();
      _toRemote(cached, skipInvite: true);
      return;
    }

    await widget.signalRelay.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.signalRelay.awaitInstallData(seconds: 10),
      widget.signalRelay.awaitDeepLink(),
    ]);
    _lift(0.7);

    final Verdict verdict = await _ask();
    _lift(1.0);
    await _settle();

    if (verdict.allowed && verdict.hasLink) {
      _toRemote(verdict.link!, skipInvite: true);
    } else if (cached != null) {
      _toRemote(cached, skipInvite: true);
    } else {
      _toOffline();
    }
  }

  Future<Verdict> _ask() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.signalRelay.assembleBody(
      locale: locale,
      pushToken: widget.alertCenter.token,
    );
    return widget.verdictChannel.query(body);
  }

  void _repostToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.signalRelay.assembleBody(
      locale: locale,
      pushToken: token,
    );
    widget.verdictChannel.query(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  // ── Routing ──

  Future<void> _goLocal({required double initialLift}) async {
    _lift(initialLift);
    // The game is portrait-only.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final StatsRepository stats = await StatsRepository.load();
    await _warmGameArt();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MainMenuScreen(stats: stats)),
    );
  }

  Future<void> _warmGameArt() async {
    for (final String path in AppAssets.preloadable) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _toRemote(String link, {bool skipInvite = false}) {
    if (_routed || !mounted) return;
    _routed = true;
    final bool offerInvite =
        !skipInvite && widget.locker.shouldOfferPushInvite();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => offerInvite
            ? PushPromptCurtain(
                locker: widget.locker,
                alertCenter: widget.alertCenter,
                reachProbe: widget.reachProbe,
                contentLink: link,
              )
            : WebCurtain(
                link: link,
                locker: widget.locker,
                alertCenter: widget.alertCenter,
                reachProbe: widget.reachProbe,
              ),
      ),
    );
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineCurtain(
          onRetryBuild: (_) => BootGate(
            locker: widget.locker,
            reachProbe: widget.reachProbe,
            signalRelay: widget.signalRelay,
            verdictChannel: widget.verdictChannel,
            alertCenter: widget.alertCenter,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape = size.width > size.height;
    final String bg =
        landscape ? AppAssets.loadingHorizontal : AppAssets.loadingVertical;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.charcoal,
        body: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bg, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: landscape ? 28 : 64,
                child: _LoadingBadge(progress: _progress, dots: _dots),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge({required this.progress, required this.dots});

  final double progress;
  final AnimationController dots;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: dots,
            builder: (context, _) {
              final int n = (dots.value * 4).floor() % 4;
              return Text(
                'Loading${'.' * n}',
                style: const TextStyle(
                  color: AppColors.emberYellow,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ProgressBar(progress: progress),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 16,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          border:
              Border.all(color: AppColors.emberOrange.withValues(alpha: 0.4)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            builder: (context, value, _) {
              return FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.emberGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emberOrange.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
