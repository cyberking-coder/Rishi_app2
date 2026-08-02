import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase Cloud Messaging, wrapped so the rest of the app never has to
/// know whether push is actually available.
///
/// Every entry point here is failure-tolerant on purpose. Push is a
/// convenience — being reminded about a Zoom call — and a missing
/// google-services.json, a denied permission or a Play-Services-less
/// handset must all end with the app running normally and no reminders,
/// never with a crash on a screen the user was trying to reach.
class PushService {
  static final _local = FlutterLocalNotificationsPlugin();

  /// Matches the channel_id the send function sets on the FCM payload.
  /// If these two ever disagree, Android silently drops the notification
  /// into the default channel and the importance settings are lost.
  static const _channel = AndroidNotificationChannel(
    'session_reminders',
    'Live session reminders',
    description: 'Reminders before a live Zoom session starts.',
    importance: Importance.high,
  );

  static bool _ready = false;

  static bool get isAvailable => _ready;

  /// Called once at boot, before runApp. Sets up Firebase and the local
  /// channel but does NOT ask for permission — that happens later, when
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
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // FCM posts its own notification when the app is backgrounded, but
      // stays silent when it is in the foreground — and a reminder that
      // arrives while someone is already using the app is the one most
      // likely to get them into the call. So re-post it here.
      FirebaseMessaging.onMessage.listen(_showForeground);

      _ready = true;
    } catch (e) {
      debugPrint('Local notification setup failed, push disabled: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      // Notification ids collide silently; hashing the message id keeps
      // two different reminders from replacing each other.
      message.messageId.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
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
  /// is dead, and reminders stop arriving with nothing to show why.
  static Stream<String> get tokenRefreshes {
    if (!_ready) return const Stream<String>.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
