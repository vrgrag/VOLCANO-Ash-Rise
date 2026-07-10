import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../wire/app_facade.dart';
import '../wire/packed_secrets.dart';
import 'agent_client.dart';

// ============================================================
// SIGNAL RELAY — AppsFlyer install attribution + deep links
// ============================================================
// Collects the install conversion payload, deep-link click event and
// app-open attribution, then folds them into the gate request body.
//
// Organic false-positive guard: AppsFlyer occasionally reports
// af_status == "Organic" on the first conversion callback for genuinely
// paid installs. When that happens we wait a few seconds and re-query the
// GCD endpoint for the real attribution.
//
// With no dev key configured yet, the relay short-circuits so the boot
// pipeline does not stall for 30s before falling back to the game.
// ============================================================

class SignalRelay {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _started = false;

  /// Initializes the SDK and wires callbacks. Safe to call once.
  Future<void> ignite() async {
    if (_started) return;
    _started = true;

    final String devKey = AshFacade.attributionKey;
    if (devKey.isEmpty) {
      // No key yet — don't block the flow waiting for attribution.
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: AshFacade.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> payload = _flatten(res);
      if (kDebugMode) {
        debugPrint('[SignalRelay] onInstallConversionData: $payload');
      }
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: AshFacade.organicRecheckDelay),
        );
        final Map<String, dynamic>? recheck = await _gcdRecheck();
        if (kDebugMode && recheck != null) {
          debugPrint('[SignalRelay] GCD retry data: $recheck');
        }
        _installData = recheck ?? payload;
      } else {
        _installData = payload;
      }
      _completeInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenData = _flatten(res);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
        if (kDebugMode) {
          debugPrint('[SignalRelay] onDeepLinking: $_deepLinkData');
        }
      }
      _completeDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
    }
  }

  /// Waits up to [seconds] for the install conversion payload.
  Future<Map<String, dynamic>> awaitInstallData({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Waits up to 5s for the deep-link callback.
  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged gate (config) request body. Attribution fields are
  /// forwarded VERBATIM; device-side fields are added last and overwrite.
  Future<Map<String, dynamic>> assembleBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installData != null) body.addAll(_installData!);
    _appOpenData
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _deepLinkData
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = AshFacade.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = AshFacade.marketId;
    body['locale'] = locale;

    // Omit push_token / firebase_project_id entirely if unavailable —
    // never send "" or null (see android_gray_guide.md §3, §5).
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String sender = AshFacade.messagingSender;
    if (sender.isNotEmpty) {
      body['firebase_project_id'] = sender;
    }

    if (kDebugMode) {
      debugPrint('[VerdictChannel] Request body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRecheck() async {
    try {
      final String? deviceId = await uid();
      if (deviceId == null) return null;
      final String appId =
          Platform.isIOS ? AshFacade.storeNumericId : AshFacade.packageId;
      final String url = unlockGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final response = await agentClient.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${AshFacade.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _completeInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _completeDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _flatten(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
