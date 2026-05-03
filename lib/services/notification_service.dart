import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  const NotificationService._();

  static const int _minutesPerDay =
      Duration.hoursPerDay * Duration.minutesPerHour;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'medication_reminders';
  static const String _channelName = 'Recordatorios de medicamentos';
  static const String _channelDescription =
      'Notificaciones locales para recordar medicamentos programados.';
  static const String _title = 'Recordatorio de medicamento';

  static Future<void> init() async {
    if (_initialized || kIsWeb) {
      return;
    }

    try {
      tz.initializeTimeZones();
      await _configureLocalTimezone();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notifications.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // Las notificaciones no deben interrumpir el flujo principal.
    }
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }

    try {
      await init();

      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    } catch (_) {
      // Los permisos se solicitan como mejora local, sin bloquear la app.
    }
  }

  static Future<void> scheduleMedicationReminder({
    required int id,
    required String nombre,
    required String dosis,
    required String hora,
    required String frecuencia,
  }) async {
    if (kIsWeb) {
      return;
    }

    try {
      await init();
      await requestPermissions();

      final _MedicationTime? baseTime = _parseMedicationTime(hora);
      if (baseTime == null) {
        return;
      }

      await cancelMedicationReminder(id);

      final List<_MedicationTime> dailyTimes = _timesForFrequency(
        baseTime,
        frecuencia,
      );

      for (int index = 0; index < dailyTimes.length; index++) {
        final _MedicationTime scheduledTime = dailyTimes[index];
        final _MedicationTime previousTime = scheduledTime.minusMinutes(10);
        final int mainId = _notificationId(id, index, previous: false);
        final int previousId = _notificationId(id, index, previous: true);

        await _scheduleDailyNotification(
          id: mainId,
          scheduledTime: scheduledTime,
          body: 'Tomar $nombre - $dosis',
        );
        await _scheduleDailyNotification(
          id: previousId,
          scheduledTime: previousTime,
          body: 'En 10 minutos debes tomar $nombre',
        );
      }
    } catch (_) {
      // Nunca debe romper la creación del recordatorio clínico.
    }
  }

  static Future<void> cancelMedicationReminder(int id) async {
    if (kIsWeb) {
      return;
    }

    try {
      await init();

      for (int index = 0; index < 24; index++) {
        await _notifications.cancel(
          id: _notificationId(id, index, previous: false),
        );
        await _notifications.cancel(
          id: _notificationId(id, index, previous: true),
        );
      }
    } catch (_) {
      // Cancelar notificaciones es best-effort.
    }
  }

  static Future<void> _configureLocalTimezone() async {
    try {
      final TimezoneInfo timezoneInfo =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> _scheduleDailyNotification({
    required int id,
    required _MedicationTime scheduledTime,
    required String body,
  }) async {
    await _notifications.zonedSchedule(
      id: id,
      title: _title,
      body: body,
      scheduledDate: _nextInstanceOf(scheduledTime),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  static tz.TZDateTime _nextInstanceOf(_MedicationTime time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static List<_MedicationTime> _timesForFrequency(
    _MedicationTime baseTime,
    String frecuencia,
  ) {
    final int? intervalHours = _parseHourlyInterval(frecuencia);
    if (intervalHours == null || intervalHours <= 0 || intervalHours >= 24) {
      return [baseTime];
    }

    final Set<int> minutesOfDay = <int>{};
    final List<_MedicationTime> times = <_MedicationTime>[];
    final int baseMinutes = baseTime.hour * 60 + baseTime.minute;
    final int intervalMinutes = intervalHours * 60;

    for (int offset = 0; offset < _minutesPerDay; offset += intervalMinutes) {
      final int minutes = (baseMinutes + offset) % _minutesPerDay;
      if (!minutesOfDay.add(minutes)) {
        continue;
      }

      times.add(_MedicationTime(minutes ~/ 60, minutes % 60));
    }

    times.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return times;
  }

  static int? _parseHourlyInterval(String frecuencia) {
    final RegExpMatch? match = RegExp(
      r'cada\s+(\d+)\s+horas?',
      caseSensitive: false,
    ).firstMatch(frecuencia.trim());

    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1) ?? '');
  }

  static _MedicationTime? _parseMedicationTime(String hora) {
    final List<String> parts = hora.trim().split(':');
    if (parts.length != 2) {
      return null;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return _MedicationTime(hour, minute);
  }

  static int _notificationId(int id, int index, {required bool previous}) {
    final int baseId = id.abs() % 1000000;
    return baseId * 100 + index * 2 + (previous ? 1 : 0);
  }
}

class _MedicationTime {
  const _MedicationTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesOfDay => hour * 60 + minute;

  _MedicationTime minusMinutes(int value) {
    final int normalizedMinutes =
        (minutesOfDay - value) % NotificationService._minutesPerDay;
    return _MedicationTime(normalizedMinutes ~/ 60, normalizedMinutes % 60);
  }
}
