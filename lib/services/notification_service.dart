import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'runmate_channel';
  static const _channelName = 'RunMate Notifications';

  Future<void> init() async {
    // Request permission (iOS prompt, Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Local notifications setup
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // Create Android notification channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));

    // Save FCM token to RTDB
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);
    _fcm.onTokenRefresh.listen(_saveToken);

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background tap → navigate
    FirebaseMessaging.onMessageOpenedApp.listen(_onRemoteTap);

    // Terminated state → app opened from notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _navigate(initial.data);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseDatabase.instance
        .ref('user_stats/$uid')
        .update({'fcmToken': token});
  }

  void _showLocalNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalTap(NotificationResponse response) {
    try {
      final data =
          jsonDecode(response.payload ?? '{}') as Map<String, dynamic>;
      _navigate(data);
    } catch (_) {}
  }

  void _onRemoteTap(RemoteMessage message) => _navigate(message.data);

  void _navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'friend_request':
      case 'friend_accepted':
        Get.toNamed(AppRoutes.home, arguments: 1); // Friends tab
        break;
      case 'leaderboard':
        Get.toNamed(AppRoutes.leaderboard);
        break;
      default:
        break;
    }
  }

  /// Call this after a user logs out to clear the token from RTDB.
  Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseDatabase.instance
        .ref('user_stats/$uid/fcmToken')
        .remove();
    await _fcm.deleteToken();
  }
}
