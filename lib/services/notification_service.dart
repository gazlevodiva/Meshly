import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Whether [init] has run. The plugin throws a `LateError` from every entry
  /// point before it is initialized, and [requestPermissions] is now called
  /// from a screen (`MainScreen`), which widget tests build without going
  /// through `main()`.
  bool _initialized = false;

  /// Callback for navigation on notification tap.
  void Function(String conversationId)? onNotificationTap;

  Future<void> init() async {
    // Notification icon — a monochrome silhouette: Android draws it based
    // on alpha, ignoring colors entirely. A full-color app icon turns into
    // a solid white rectangle here.
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final convId = details.payload;
        if (convId != null) onNotificationTap?.call(convId);
      },
    );
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (!_initialized) {
      debugPrint('[Notifications] requestPermissions before init — skipped');
      return;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showMessage({
    required String title,
    required String body,
    required String conversationId,
  }) async {
    await _plugin.show(
      conversationId.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          // TODO(l10n): Android notification-channel name shown in system
          // settings. NotificationService has no BuildContext, so this stays
          // a Russian literal until localization is plumbed through.
          'Сообщения',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: conversationId,
    );
    debugPrint('[Notification] shown for conversation $conversationId');
  }
}
