import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_client.dart';
import 'locker.dart';

// ============================================================
// ALERT CENTER — Firebase Messaging + local notification display
// ============================================================
// Cold-start taps (app was killed) save the link so the shell opens it on
// next boot. Warm taps (background/foreground) deliver the link live via
// [onLink] without persisting it (push links are one-time).
//
// The channel id below must EXACTLY match the manifest meta-data
// `default_notification_channel_id`. The small icon is a dedicated flame
// vector (res/drawable/ic_notification.xml), never the launcher icon.
const String kAlertChannelId = 'ember_alerts';
const String kAlertChannelName = 'Promotions & Offers';
const String _smallIcon = 'ic_notification';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS renders background notifications; the tap is processed on
  // resume (warm) or boot (cold) — nothing to do in this isolate.
}

class AlertCenter {
  AlertCenter(this._locker);

  final Locker _locker;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Live (warm) push link delivery → loaded straight into the WebView.
  void Function(String link)? onLink;

  /// Fired when FCM rotates the token → re-post to the gate.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _setupLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant, app continues.
    }
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) onLink?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? impl =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(
        const AndroidNotificationChannel(
          kAlertChannelId,
          kAlertChannelName,
          description: 'Updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks for notification permission (Android 13+ system dialog). Records an
  /// OS-denied flag so the invite screen never loops (guide §"OS-denied").
  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _locker.markPushAllowed(granted);
    if (status == AuthorizationStatus.denied) {
      await _locker.markPushBlockedByOs();
    }
    return granted;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kAlertChannelId,
          kAlertChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kAlertChannelId,
      kAlertChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      _locker.stashPendingLink(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      onLink?.call(link);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final response = await agentClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
