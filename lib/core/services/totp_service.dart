import 'dart:math';

import 'package:crypto/crypto.dart';

/// Implementação de TOTP (RFC 6238) para autenticação em dois fatores (cap. 71).
///
/// Suporta os apps autenticadores padrão (Google Authenticator, Authy, etc.):
/// - Segredo em Base32;
/// - Janela de 30 s, 6 dígitos, algoritmo HMAC-SHA1;
/// - QR Code montado como URL otpauth:// (renderizado sem dependências extra).
///
/// Nenhum dado sai do dispositivo: o segredo fica apenas no banco local.
class TotpService {
  const TotpService._();

  static const int digits = 6;
  static const int period = 30;

  /// Gera um novo segredo Base32 (20 bytes aleatórios = 160 bits).
  static String generateSecret({int bytes = 20}) {
    final rnd = Random.secure();
    final data = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return _base32Encode(data);
  }

  /// URL otpauth:// para renderizar no QR Code.
  static String otpauthUri({
    required String secret,
    required String account,
    required String issuer,
  }) {
    final label = Uri.encodeComponent('$issuer:$account');
    final params = {
      'secret': secret,
      'issuer': issuer,
      'algorithm': 'SHA1',
      'digits': '$digits',
      'period': '$period',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'otpauth://totp/$label?$query';
  }

  /// Código TOTP atual para um segredo Base32.
  /// [now] e [skew] permitem testar/validar janelas adjacentes.
  static String code(String secret, {DateTime? now, int skew = 0}) {
    final counter = (_counter(now ?? DateTime.now()) + skew);
    final key = _base32Decode(secret);
    final msg = _int64Bytes(counter);
    final hmac = Hmac(sha1, key).convert(msg).bytes;
    final offset = hmac[hmac.length - 1] & 0x0f;
    final bin = ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    final otp = bin % pow(10, digits).toInt();
    return otp.toString().padLeft(digits, '0');
  }

  /// Verifica um código aceitando ±1 janela (±30 s) por tolerância de relógio.
  static bool verify(String secret, String input, {DateTime? now}) {
    final clean = input.replaceAll(RegExp(r'\D'), '');
    if (clean.length != digits) return false;
    final at = now ?? DateTime.now();
    for (final skew in [-1, 0, 1]) {
      if (code(secret, now: at, skew: skew) == clean) return true;
    }
    return false;
  }

  /// Segundos restantes até o código atual expirar.
  static int secondsRemaining({DateTime? now}) {
    final s = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return period - (s % period);
  }

  static int _counter(DateTime now) =>
      (now.toUtc().millisecondsSinceEpoch ~/ 1000) ~/ period;

  static List<int> _int64Bytes(int value) {
    final b = List<int>.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      b[i] = value & 0xff;
      value >>= 8;
    }
    return b;
  }

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String _base32Encode(List<int> data) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in data) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 0x1f]);
      }
    }
    if (bits > 0) {
      out.write(_alphabet[(buffer << (5 - bits)) & 0x1f]);
    }
    return out.toString();
  }

  static List<int> _base32Decode(String input) {
    final clean = input.replaceAll('=', '').replaceAll(' ', '').toUpperCase();
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) continue;
      buffer = (buffer << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return out;
  }
}
