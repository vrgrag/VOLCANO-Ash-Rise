import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'gate/boot_gate.dart';
import 'relay/alert_center.dart';
import 'relay/locker.dart';
import 'relay/reach_probe.dart';
import 'relay/signal_relay.dart';
import 'relay/verdict_channel.dart';

/// Root widget. Owns the long-lived services and hands them to the boot gate.
class AshRiseApp extends StatelessWidget {
  const AshRiseApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ash Rise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.charcoal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.emberOrange,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: BootGate(
        locker: locker,
        reachProbe: reachProbe,
        signalRelay: signalRelay,
        verdictChannel: verdictChannel,
        alertCenter: alertCenter,
      ),
    );
  }
}
