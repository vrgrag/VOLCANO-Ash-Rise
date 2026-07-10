import 'packed_secrets.dart';
import 'public_links.dart';

// ============================================================
// APP FACADE — single access point for app-wide constants
// ============================================================
// Identity values are plain; endpoints/credentials resolve lazily
// through the scrambler so plaintext never lands in the binary.
// ============================================================

class AshFacade {
  AshFacade._();

  // ── Identity ──
  // Must stay in exact sync with:
  //   • android/app/build.gradle.kts → applicationId + namespace
  //   • android/app/src/main/kotlin/**/MainActivity.kt package
  //   • android/app/google-services.json → package_name (when added)
  static const String packageId = 'com.ashrise.ashrise';
  static const String marketId = 'com.ashrise.ashrise'; // == packageId on Android
  static const String displayName = 'Ash Rise';

  // iOS App Store numeric id (unused on this Android-only build).
  static const String storeNumericId = '';

  // ── Resolved endpoints / credentials (scrambled at rest) ──
  static String get gateEndpoint => unlockConfigEndpoint();
  static String get attributionKey => unlockAttributionKey();
  static String get messagingSender => unlockMessagingSender();

  // ── Public links ──
  static const String privacyUrl = privacyPolicyLink;
  static const String helpUrl = supportLink;
  static const String homeUrl = siteHome;

  // ── Timing knobs ──
  /// Re-offer the push invite this many seconds after a Skip (3 days).
  static const int pushInviteCooldown = 3 * 24 * 60 * 60;

  /// Delay before the organic-false-positive GCD re-check.
  static const int organicRecheckDelay = 5;
}
