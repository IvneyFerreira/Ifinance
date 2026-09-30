import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_spec.dart';

/// Notificações nativas agendadas (Android/iOS) — lembretes de vencimento.
///
/// Este arquivo usa plugins nativos e só é importado em plataformas IO
/// (ver conditional import em notification_service.dart).

const bool notificationsSupported = true;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;

const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
  'ifinance_lembretes',
  'Lembretes de contas e recebimentos',
  channelDescription: 'Avisos de contas a vencer e valores a receber',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
);

Future<void> initNotifications() async {
  if (_initialized) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _plugin.initialize(settings: settings);
  await _configureTimezone();
  _initialized = true;
}

Future<void> _configureTimezone() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    // Mantém o fuso padrão (UTC) caso a leitura falhe.
  }
}

/// Pede permissão de notificação (Android 13+) e de alarme exato.
Future<bool> requestNotificationPermission() async {
  if (!Platform.isAndroid) return true;
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return false;
  final granted = await android.requestNotificationsPermission() ?? false;
  // Tenta também o alarme exato (ignora se não aplicável/negado).
  try {
    await android.requestExactAlarmsPermission();
  } catch (_) {}
  return granted;
}

Future<void> scheduleReminders(List<ReminderSpec> specs) async {
  await initNotifications();
  await _plugin.cancelAll();
  final now = tz.TZDateTime.now(tz.local);
  for (final s in specs) {
    var when = tz.TZDateTime.from(s.when, tz.local);
    // Se o horário já passou, dispara em 1 minuto (evita erro de agendamento).
    if (when.isBefore(now)) when = now.add(const Duration(minutes: 1));
    AndroidScheduleMode mode = AndroidScheduleMode.exactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id: s.id,
        title: s.title,
        body: s.body,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
            android: _androidDetails,
            iOS: DarwinNotificationDetails()),
        androidScheduleMode: mode,
      );
    } catch (_) {
      // Fallback: agenda sem garantia de exatidão.
      try {
        await _plugin.zonedSchedule(
          id: s.id,
          title: s.title,
          body: s.body,
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
              android: _androidDetails,
              iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }
}

Future<void> cancelAllReminders() async {
  await _plugin.cancelAll();
}
