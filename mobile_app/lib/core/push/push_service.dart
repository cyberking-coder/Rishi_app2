import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase Cloud Messaging, wrapped so the rest of the app never has to
/// know whether push is actually available.
///
/// Every entry point here is failure-tolerant on purpose. Push is a
/// convenience — a reminder about a Zoom call, a nudge about a new
/// meditation — and a missing google-services.json, a denied permission
/// or a Play-Services-less handset must all end with the app running
/// normally and no notifications, never with a crash on a screen the
/// user was trying to reach.
class PushService {
  static final _local = FlutterLocalNotificationsPlugin();

  /// Two channels, not one, so someone can mute the morning nudge without
  /// also losing the reminder that a session they signed up for is about
  /// to start. Each id must match the channel_id the sending function
  /// puts on its payload — if they disagree, Android quietly files the
  /// notification under a default channel and the importance is lost.
  static const _sessionChannel = AndroidNotificationChannel(
    'session_reminders',
    'Live session reminders',
    description: 'Reminders before a live Zoom session starts.',
    importance: Importance.high,
  );

  static const _contentChannel = AndroidNotificationChannel(
    'content_updates',
    'New content and daily meditation',
    description:
        'New courses and meditations, and the daily "start your day" audio.',
    importance: Importance.defaultImportance,
  );

  /// Where a tapped notification wants to go, as a go_router path. A
  /// broadcast stream because both the app shell and a cold start may be
  /// listening, and neither should consume the other's event.
  static final _deepLinks = StreamController<String>.broadcast();

  static Stream<String> get deepLinks => _deepLinks.stream;

  /// A tap that launched the app from cold. It arrives before any widget
  /// exists to receive it, so it is held here until something asks —
  /// otherwise the one notification most likely to be tapped (the app
  /// wasn't open, that's why they were notified) would be the one that
  /// went nowhere.
  static String? pendingDeepLink;

  static bool _ready = false;

  static bool get isAvailable => _ready;

  /// Called once at boot, before runApp. Sets up Firebase and the local
  /// channels but does NOT ask for permission — that happens later, when
  /// the user is somewhere the request makes sense.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // The overwhelmingly common cause is google-services.json not
      // being in android/app. Say so, rather than leaving a bare
      // platform exception in the log.
      debugPrint(
        'Firebase not initialised, push disabled: $e\n'
        'If this is a local build, check android/app/google-services.json.',
      );
      return;
    }

    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        // A foreground notification is posted by the local plugin, so its
        // tap comes back here rather than through FCM. Without this, the
        // notifications most likely to be seen would be the ones that
        // couldn't be tapped through.
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _emit(payload);
        },
      );

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_sessionChannel);
      await android?.createNotificationChannel(_contentChannel);

      // FCM posts its own notification when the app is backgrounded, but
      // stays silent when it is in the foreground — and a nudge that
      // arrives while someone is already using the app is the one most
      // likely to be acted on. So re-post it here.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Tapped while the app was alive in the background.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final link = _linkFrom(message);
        if (link != null) _emit(link);
      });

      // Tapped from cold. Held rather than emitted: nothing is listening
      // this early.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) pendingDeepLink = _linkFrom(initial);

      _ready = true;
    } catch (e) {
      debugPrint('Local notification setup failed, push disabled: $e');
    }
  }

  static String? _linkFrom(RemoteMessage message) {
    final link = message.data['deep_link'];
    return (link is String && link.isNotEmpty) ? link : null;
  }

  static void _emit(String link) {
    if (!_deepLinks.isClosed) _deepLinks.add(link);
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Falls back to the content channel rather than the session one: a
    // payload with no channel is far more likely to be an announcement,
    // and guessing "high importance" wrong is the more intrusive error.
    final channel = message.notification?.android?.channelId ==
            _sessionChannel.id
        ? _sessionChannel
        : _contentChannel;

    await _local.show(
      // Notification ids collide silently; hashing the message id keeps
      // two different notifications from replacing each other.
      message.messageId.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
        ),
      ),
      payload: _linkFrom(message),
    );
  }

  /// Asks for permission and returns this device's token, or null if push
  /// is unavailable or the user said no.
  ///
  /// Safe to call repeatedly: after the first answer the OS returns the
  /// stored decision without showing anything.
  static Future<String?> requestToken() async {
    if (!_ready) return null;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Could not get an FCM token: $e');
      return null;
    }
  }

  /// This device's token without prompting for anything. Used on
  /// sign-out, where asking for permission would be absurd and the only
  /// question is which row to delete.
  static Future<String?> currentToken() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Could not read the FCM token: $e');
      return null;
    }
  }

  /// Fires when FCM reissues a token — which it does on reinstall, on a
  /// restore to a new handset, and occasionally for no visible reason.
  /// Without this the app keeps a token the server has already been told
  /// is dead, and notifications stop arriving with nothing to show why.
  static Stream<String> get tokenRefreshes {
    if (!_ready) return const Stream<String>.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
