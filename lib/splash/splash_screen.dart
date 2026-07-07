import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/storage/stats_repository.dart';
import '../menu/main_menu_screen.dart';

/// Splash / loading screen.
///
/// The progress bar is driven exclusively by real asset pre-caching work,
/// so it is physically impossible for it to reach 100% before the app has
/// actually finished loading everything it needs. The background artwork
/// adapts to the current device orientation (portrait or landscape), while
/// the rest of the game is locked to portrait once loading completes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  late final AnimationController _dotsController;
  StatsRepository? _stats;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _runLoadSequence();
  }

  Future<void> _runLoadSequence() async {
    final tasks = <Future<void> Function()>[
      () => StatsRepository.load().then((s) => _stats = s),
      ...AppAssets.preloadable.map(
        (path) => () => precacheImage(AssetImage(path), context),
      ),
    ];

    final total = tasks.length;
    var completed = 0;

    for (final task in tasks) {
      try {
        await task();
      } catch (_) {
        // Never let a single missing/broken asset block the whole app.
      }
      completed++;
      if (!mounted) return;
      setState(() => _progress = completed / total);
    }

    // Small grace pause so the user actually sees the bar reach 100%.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainMenuScreen(stats: _stats!)),
    );
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final background =
        isLandscape ? AppAssets.loadingHorizontal : AppAssets.loadingVertical;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(background, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: isLandscape ? 28 : 64,
            child: _LoadingIndicator(
              progress: _progress,
              dotsController: _dotsController,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({
    required this.progress,
    required this.dotsController,
  });

  final double progress;
  final AnimationController dotsController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: dotsController,
            builder: (context, _) {
              final dotCount = (dotsController.value * 4).floor() % 4;
              return Text(
                'Loading${'.' * dotCount}',
                style: const TextStyle(
                  color: AppColors.emberYellow,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
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
          border: Border.all(color: AppColors.emberOrange.withValues(alpha: 0.4)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
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
