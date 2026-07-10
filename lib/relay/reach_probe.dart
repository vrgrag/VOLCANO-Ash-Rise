import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// REACH PROBE — connectivity + real reachability check
// ============================================================
// [isReachable] does a real DNS probe (not just the adapter state) so
// captive / limited networks are treated as offline.
//
// Fixes baked in from gray_part_pitfalls.md §3:
//   • VPN / bluetooth / ethernet / other all count as "connectivity"
//     (VPN interfaces briefly report `none` while coming up).
//   • DNS probe timeout raised to 7s — genuine no-route cases throw a
//     SocketException instantly, so the larger timeout is free and stops
//     false-negatives on slow VPN tunnels.
// ============================================================

class ReachProbe {
  ReachProbe({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  Future<bool> isReachable() async {
    final List<ConnectivityResult> states =
        await _connectivity.checkConnectivity();
    if (!states.any(_liveAdapters.contains)) return false;

    try {
      final List<InternetAddress> probe = await InternetAddress.lookup(
        'cloudflare.com',
      ).timeout(const Duration(seconds: 7));
      return probe.isNotEmpty && probe.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
