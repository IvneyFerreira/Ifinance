import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as sha;

/// Criptografia do **backup na nuvem** (cap. 73).
///
/// Privacidade por padrão: o backup sobe **cifrado** com uma chave derivada da
/// senha do próprio usuário (PBKDF2 + AES-GCM). O servidor nunca vê a senha e
/// NÃO consegue ler os dados — se alguém obtiver o arquivo, sem a senha ele é
/// inútil.
///
/// Formato do "envelope" gravado no servidor:
///   { "v": 1, "kdf": "pbkdf2-sha256", "iter": 120000,
///     "salt": "<b64>", "blob": "<b64 nonce(12) || ciphertext+mac>" }
class SyncCrypto {
  SyncCrypto._();

  static const int _iterations = 120000;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;
  static const String _kdfLabel = 'pbkdf2-sha256';

  static final _algorithm = AesGcm.with256bits();
  static Pbkdf2 _pbkdf2(int iterations) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

  /// Identificador opaco da conta usado como chave no servidor.
  ///
  /// É o SHA-256 do e-mail normalizado (não reversível) — assim o servidor não
  /// guarda o e-mail em claro e continua isolando os dados por conta.
  static String accountId(String email) {
    final normalized = email.trim().toLowerCase();
    return sha.sha256.convert(utf8.encode('ifinance:v1:$normalized')).toString();
  }

  static String randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => rnd.nextInt(256));
    return base64Encode(bytes);
  }

  static Future<SecretKey> _key(String password, String saltB64) async {
    final salt = base64Decode(saltB64);
    return _pbkdf2(_iterations).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Cifra um JSON (String) e devolve o envelope pronto para enviar ao servidor.
  static Future<Map<String, dynamic>> seal({
    required String password,
    required String plaintextJson,
    String? saltB64,
  }) async {
    final salt = saltB64 ?? randomSalt();
    final key = await _key(password, salt);
    final box = await _algorithm.encrypt(
      utf8.encode(plaintextJson),
      secretKey: key,
    );
    final payload = Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
    return {
      'v': 1,
      'kdf': _kdfLabel,
      'iter': _iterations,
      'salt': salt,
      'blob': base64Encode(payload),
    };
  }

  /// Decifra o envelope recebido do servidor. Lança se a senha estiver errada
  /// (falha de autenticação do AES-GCM) ou se o conteúdo estiver corrompido.
  static Future<String> open({
    required String password,
    required Map<String, dynamic> envelope,
  }) async {
    final salt = (envelope['salt'] ?? '') as String;
    final blob = (envelope['blob'] ?? '') as String;
    if (salt.isEmpty || blob.isEmpty) {
      throw const SyncCryptoException('Backup na nuvem vazio ou inválido.');
    }
    final iterations = (envelope['iter'] as num?)?.toInt() ?? _iterations;
    final key = await _pbkdf2(iterations).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(salt),
    );
    final raw = base64Decode(blob);
    if (raw.length <= _nonceBytes) {
      throw const SyncCryptoException('Backup na nuvem corrompido.');
    }
    final nonce = raw.sublist(0, _nonceBytes);
    final macLength = 16;
    final cipherText = raw.sublist(_nonceBytes, raw.length - macLength);
    final mac = Mac(raw.sublist(raw.length - macLength));
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException(
          'Senha incorreta para o backup na nuvem.');
    } catch (_) {
      throw const SyncCryptoException('Falha ao abrir o backup na nuvem.');
    }
  }
}

class SyncCryptoException implements Exception {
  final String message;
  const SyncCryptoException(this.message);
  @override
  String toString() => message;
}
