import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../wire/app_facade.dart';
import '../wire/packed_secrets.dart';

// ============================================================
// AGENT CLIENT — http client wearing a real device user-agent
// ============================================================
// The gate POST, the GCD retry, the push-image fetch and the WebView all
// share ONE user-agent that mimics the device's real Chrome. A default
// Dart UA (which leaks "Dart"/"Flutter") would be an obvious fingerprint.
//
// Chrome/WebKit fragments are decoded from packed_secrets. Chrome major
// is 149 per .cursor/rules/gray_user_agent.mdc; the exact build/patch is
// unique to this project (149.0.7742.118).
//
// ── GAME THEME CATEGORY: crash (no appid/appname suffix) ──
// The Ash Rise game is a volcanic timing/precision arcade title, not a
// spinning-reel/roulette slot. Per gray_user_agent.mdc §2 the identity
// suffix is only appended for SLOT themes and must NOT appear on a crash
// build. If the partner confirms this is actually a slot placement, flip
// [_appendSlotIdentity] to true (single-line change) and ship a fresh
// build — the value is cached server-side per install.
const bool _appendSlotIdentity = false;

class AgentClient extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _ua = 'Mozilla/5.0';

  String get userAgent => _ua;

  /// Reads device info and assembles the user-agent. Call once in main().
  Future<void> prime() async {
    final String chrome = _orElse(unlockChromeVersion(), '149.0.0.0');
    final String webkit = _orElse(unlockWebkitVersion(), '537.36');

    String base;
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await plugin.androidInfo;
        final String tag = a.display.isNotEmpty ? a.display : a.id;
        base = 'Mozilla/5.0 (Linux; Android ${a.version.release}; '
            '${a.brand} ${a.model} Build/$tag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo i = await plugin.iosInfo;
        final String os = i.systemVersion.replaceAll('.', '_');
        base = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$webkit';
      } else {
        base = _fallback(chrome, webkit);
      }
    } catch (_) {
      base = _fallback(chrome, webkit);
    }

    if (_appendSlotIdentity) {
      final String appName = AshFacade.displayName.replaceAll(' ', '');
      base = '$base appid/${AshFacade.packageId} appname/$appName';
    }
    _ua = base;
  }

  static String _fallback(String chrome, String webkit) =>
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.231005.007) '
      'AppleWebKit/$webkit (KHTML, like Gecko) '
      'Chrome/$chrome Mobile Safari/$webkit';

  static String _orElse(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client used by every networking service.
final AgentClient agentClient = AgentClient();
