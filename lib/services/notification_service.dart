import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderTypeInfo {
  final String id;
  final String label;
  final String notificationTitle;
  final String notificationBody;
  final String payload;

  const ReminderTypeInfo({
    required this.id,
    required this.label,
    required this.notificationTitle,
    required this.notificationBody,
    required this.payload,
  });
}

const List<ReminderTypeInfo> kReminderTypes = [
  ReminderTypeInfo(
    id: 'whatsapp_messages',
    label: 'ગ્રાહકોને WhatsApp મેસેજ મોકલો 💬',
    notificationTitle: 'દૂધનો હિસાબ અને WhatsApp મેસેજ 🥛',
    notificationBody:
        'ભાઈ તમારે WhatsApp માં બધા કસ્ટમરને મેસેજ મોકલવાનો ટાઈમ થઈ ગયો છે! દૂધનો હિસાબ ચેક કરી મેસેજ મોકલો.',
    payload: 'whatsapp_messages',
  ),
  ReminderTypeInfo(
    id: 'check_ledger',
    label: 'દૂધ કલેક્શન અને હિસાબ ચેક કરો 📊',
    notificationTitle: 'દૂધનો હિસાબ અને એન્ટ્રી ચેક કરો 📊',
    notificationBody:
        'બપોરના દૂધ કલેક્શનની એન્ટ્રીઓ અને ગ્રાહકોનો હિસાબ ચેક કરવાનો સમય થઈ ગયો છે.',
    payload: 'check_ledger',
  ),
  ReminderTypeInfo(
    id: 'morning_delivery',
    label: 'સવારનું દૂધ વિતરણ / ડિલિવરી 🛵',
    notificationTitle: 'સવારનું દૂધ વિતરણ 🛵',
    notificationBody:
        'સુપ્રભાત! સવારના દૂધ વિતરણ અને કલેક્શન શરૂ કરવાનો સમય થઈ ગયો છે.',
    payload: 'morning_delivery',
  ),
];

ReminderTypeInfo getReminderTypeInfo(String id) {
  return kReminderTypes.firstWhere(
    (t) => t.id == id,
    orElse: () => kReminderTypes[0],
  );
}

class ReminderSlot {
  final String id;
  int hour;
  int minute;
  String type;
  bool isEnabled;

  ReminderSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.type,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'type': type,
        'isEnabled': isEnabled,
      };

  factory ReminderSlot.fromJson(Map<String, dynamic> json) => ReminderSlot(
        id: json['id'] as String? ?? 'slot_${DateTime.now().millisecondsSinceEpoch}',
        hour: json['hour'] as int? ?? 22,
        minute: json['minute'] as int? ?? 0,
        type: json['type'] as String? ?? 'whatsapp_messages',
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  ReminderSlot copyWith({
    String? id,
    int? hour,
    int? minute,
    String? type,
    bool? isEnabled,
  }) =>
      ReminderSlot(
        id: id ?? this.id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        type: type ?? this.type,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  String get formattedTime {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '${h12.toString().padLeft(2, '0')}:$minuteStr $ampm';
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _prefKeySlots = 'daily_reminder_slots';

  static List<ReminderSlot> getDefaultSlots() => [
        ReminderSlot(
          id: 'slot_afternoon',
          hour: 14,
          minute: 0,
          type: 'check_ledger',
          isEnabled: true,
        ),
        ReminderSlot(
          id: 'slot_night',
          hour: 22,
          minute: 0,
          type: 'whatsapp_messages',
          isEnabled: true,
        ),
      ];

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
            'Daily scheduled reminders for WhatsApp messages and collection checks.',
        importance: Importance.high,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;

      // Reschedule all active reminders from saved preferences (or default 2 slots)
      await rescheduleAll();
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

  Future<List<ReminderSlot>> getSavedSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKeySlots);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded
            .map((item) => ReminderSlot.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      developer.log('Error reading saved slots: $e');
    }
    // Default to the 2 required daily slots: 2:00 PM and 10:00 PM
    return getDefaultSlots();
  }

  Future<void> saveSlots(List<ReminderSlot> slots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(slots.map((s) => s.toJson()).toList());
      await prefs.setString(_prefKeySlots, jsonStr);
      await rescheduleAll(slots);
    } catch (e) {
      developer.log('Error saving slots: $e');
    }
  }

  Future<void> rescheduleAll([List<ReminderSlot>? customSlots]) async {
    try {
      final slots = customSlots ?? await getSavedSlots();

      // Cancel previous scheduled reminder IDs (1000 - 1050)
      for (int i = 0; i <= 50; i++) {
        await flutterLocalNotificationsPlugin.cancel(1000 + i);
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'dairy_daily_reminders',
        'Daily Milk Reminders',
        channelDescription:
            'Daily scheduled reminders for WhatsApp messages and collection checks.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      int activeIndex = 0;
      for (final slot in slots) {
        if (!slot.isEnabled) continue;

        final now = tz.TZDateTime.now(tz.local);
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          slot.hour,
          slot.minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final typeInfo = getReminderTypeInfo(slot.type);

        await flutterLocalNotificationsPlugin.zonedSchedule(
          1000 + activeIndex,
          typeInfo.notificationTitle,
          typeInfo.notificationBody,
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: typeInfo.payload,
        );

        developer.log(
          'Daily reminder scheduled #${activeIndex + 1}: ${slot.formattedTime} - ${typeInfo.label}',
        );
        activeIndex++;
      }
    } catch (e) {
      developer.log('Error rescheduling daily reminders: $e');
    }
  }

  Future<void> showTestNotification([String type = 'whatsapp_messages']) async {
    try {
      final typeInfo = getReminderTypeInfo(type);
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'dairy_daily_reminders',
        'Daily Milk Reminders',
        channelDescription:
            'Daily scheduled reminders for WhatsApp messages and collection checks.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        9999,
        typeInfo.notificationTitle,
        typeInfo.notificationBody,
        platformDetails,
        payload: typeInfo.payload,
      );
    } catch (e) {
      developer.log('Error showing test notification: $e');
    }
  }
}
