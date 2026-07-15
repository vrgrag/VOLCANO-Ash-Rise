import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'bridge/insight.dart';
import 'relay/agent_client.dart';
import 'relay/alert_center.dart';
import 'relay/locker.dart';
import 'relay/reach_probe.dart';
import 'relay/signal_relay.dart';
import 'relay/verdict_channel.dart';

// ============================================================
// Bootstrap
// ============================================================
// Wiring order (do not reshuffle without reading the guide):
//   1. Ensure bindings.
//   2. Firebase + App Check — wrapped in try/catch; the project ships
//      without google-services.json until Firebase lands, and a failure
//      here must never block startup (the app just falls back to the game).
//   3. Orientation whitelist — all four so loading + WebView rotate; the
//      game re-locks to portrait inside BootGate._goLocal.
//   4. Transparent status bar so the loading artwork goes edge-to-edge.
//   5. agentClient.prime() — forge the device User-Agent used by BOTH the
//      config HTTP call and the WebView.
//   6. locker.warmUp() — read SharedPreferences so BootGate can pick the
//      route synchronously (no blank splash).
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await agentClient.prime();

  final Locker locker = Locker();
  await locker.warmUp();

  final ReachProbe reachProbe = ReachProbe();
  final SignalRelay signalRelay = SignalRelay();
  final VerdictChannel verdictChannel = VerdictChannel(locker);
  final AlertCenter alertCenter = AlertCenter(locker);

  runApp(ClarityWidget(
    clarityConfig: Insight.config,
    app: AshRiseApp(
      locker: locker,
      reachProbe: reachProbe,
      signalRelay: signalRelay,
      verdictChannel: verdictChannel,
      alertCenter: alertCenter,
    ),
  ));
}
