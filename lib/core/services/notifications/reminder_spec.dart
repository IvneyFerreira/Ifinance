/// Especificação de um lembrete agendado (share entre stub e IO).
class ReminderSpec {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  const ReminderSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });
}
