import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          developer.log('Notification tapped: ${response.payload}');
          if (onNotificationTap != null) {
            onNotificationTap(response.payload);
          }
        },
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'dairy_daily_reminders',
        'Daily Milk Reminders',
        description:
            'Daily evening reminder to send milk collection WhatsApp messages to customers.',
        importance: Importance.high,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;

      // Schedule daily reminder at 22:00 (10:00 PM)
      await scheduleDailyWhatsAppReminder(hour: 22, minute: 0);
    } catch (e, stack) {
      developer.log('Failed to initialize NotificationService: $e',
          error: e, stackTrace: stack);
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    } catch (e) {
      developer.log('Request notifications permission error: $e');
    }
  }

  Future<void> scheduleDailyWhatsAppReminder({
    int hour = 22,
    int minute = 0,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'dairy_daily_reminders',
        'Daily Milk Reminders',
        channelDescription:
            'Daily evening reminder to send milk collection WhatsApp messages to customers.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        1001,
        'દૂધનો હિસાબ અને WhatsApp મેસેજ 🥛',
        'ભાઈ તમારે WhatsApp માં બધા કસ્ટમરને મેસેજ મોકલવાનો ટાઈમ થઈ ગયો છે! દૂધનો હિસાબ ચેક કરી મેસેજ મોકલો.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'whatsapp_messages',
      );
      developer.log(
          'Daily WhatsApp reminder scheduled for $hour:$minute every day.');
    } catch (e) {
      developer.log('Error scheduling daily reminder: $e');
    }
  }

  Future<void> showTestNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'dairy_daily_reminders',
        'Daily Milk Reminders',
        channelDescription:
            'Daily evening reminder to send milk collection WhatsApp messages to customers.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        999,
        'દૂધનો હિસાબ અને WhatsApp મેસેજ 🥛',
        'ભાઈ તમારે WhatsApp માં બધા કસ્ટમરને મેસેજ મોકલવાનો ટાઈમ થઈ ગયો છે! દૂધનો હિસાબ ચેક કરી મેસેજ મોકલો.',
        platformDetails,
        payload: 'whatsapp_messages',
      );
    } catch (e) {
      developer.log('Error showing test notification: $e');
    }
  }
}
