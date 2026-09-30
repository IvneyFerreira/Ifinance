import 'package:local_auth/local_auth.dart';

/// Biometria nativa (digital/rosto) para desbloquear o app — cap. 71.

const bool biometricSupported = true;

final LocalAuthentication _auth = LocalAuthentication();

Future<bool> biometricAvailability() async {
  try {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return canCheck || supported;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAvailable() => biometricAvailability();

Future<bool> authenticateBiometric({
  String reason = 'Autentique-se para continuar',
}) async {
  try {
    return await _auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  } catch (_) {
    return false;
  }
}
