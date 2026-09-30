import 'reminder_spec.dart';

/// Implementação no-op para plataformas sem notificações nativas (Web).
/// Mantém a mesma API para que o restante do app compile sem ramificações.

const bool notificationsSupported = false;

Future<void> initNotifications() async {}

Future<bool> requestNotificationPermission() async => false;

/// No Web não agendamos notificações nativas; a central in-app cobre o caso.
Future<void> scheduleReminders(List<ReminderSpec> specs) async {}

Future<void> cancelAllReminders() async {}
