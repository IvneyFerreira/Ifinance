/// Stub de biometria para Web: recurso indisponível.
library;

const bool biometricSupported = false;

Future<bool> biometricAvailability() async => false;

Future<bool> biometricAvailable() async => false;

Future<bool> authenticateBiometric({
  String reason = 'Autentique-se para continuar',
}) async =>
    false;
