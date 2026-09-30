/// Fachada de autenticação biométrica com seleção por plataforma.
/// No Web usa o stub (indisponível); em Android/iOS usa `local_auth`.
library;

export 'biometric_service_stub.dart'
    if (dart.library.io) 'biometric_service_io.dart';
