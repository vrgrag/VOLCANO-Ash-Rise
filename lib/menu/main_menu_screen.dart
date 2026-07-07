import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/storage/stats_repository.dart';
import '../game/game_screen.dart';
import '../webview/web_view_screen.dart';
import '../widgets/ember_button.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.stats});

  final StatsRepository stats;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.stats.soundEnabled;
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(stats: widget.stats)),
    );
    if (mounted) setState(() {});
  }

  void _openWeb(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }

  Future<void> _toggleSound() async {
    setState(() => _soundEnabled = !_soundEnabled);
    await widget.stats.setSoundEnabled(_soundEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.backgroundVolcano, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: _SoundToggle(
                      enabled: _soundEnabled,
                      onTap: _toggleSound,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      final dy = -6 + _floatController.value * 12;
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      AppAssets.logo,
                      width: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StatsPanel(stats: widget.stats),
                  const SizedBox(height: 28),
                  EmberButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    onTap: _play,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LinkText(
                        label: 'Privacy Policy',
                        onTap: () => _openWeb('Privacy Policy', AppLinks.privacyPolicy),
                      ),
                      const SizedBox(width: 20),
                      Container(width: 1, height: 12, color: Colors.white24),
                      const SizedBox(width: 20),
                      _LinkText(
                        label: 'Support',
                        onTap: () => _openWeb('Support', AppLinks.support),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final StatsRepository stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.emberOrange.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatItem(icon: Icons.emoji_events_rounded, label: 'Best', value: '${stats.bestScore}'),
          const SizedBox(width: 22),
          _StatItem(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '${stats.maxStreak}'),
          const SizedBox(width: 22),
          _StatItem(icon: Icons.center_focus_strong_rounded, label: 'Perfect', value: '${stats.perfectHitsTotal}'),
          const SizedBox(width: 22),
          _StatItem(icon: Icons.adjust_rounded, label: 'Stopped', value: '${stats.stoppedObjectsTotal}'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.emberYellow, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: const TextStyle(color: AppColors.ashGrey, fontSize: 10)),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ashGrey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.ashGrey,
        ),
      ),
    );
  }
}

class _SoundToggle extends StatelessWidget {
  const _SoundToggle({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
