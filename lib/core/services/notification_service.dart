/// Fachada de notificações com seleção de implementação por plataforma.
///
/// No Web usa o stub (no-op); em Android/iOS usa notificações nativas.
library;

export 'notifications/notification_service_stub.dart'
    if (dart.library.io) 'notifications/notification_service_io.dart';
