import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente do servidor *relying party* de WebAuthn (passkeys) — cap. 71.
///
/// O servidor (`server.py`) guarda as chaves públicas e verifica as
/// assinaturas. Este cliente apenas troca mensagens: pede as opções de
/// registro/login, entrega a resposta do autenticador e recebe o resultado.
///
/// Configuração:
///   --dart-define=PASSKEY_API_BASE=https://seu-dominio.com
/// (vazio = mesma origem do app web).
class PasskeyApi {
  PasskeyApi({http.Client? client, this.baseUrl = ''})
      : _client = client ?? http.Client();

  final http.Client _client;

  final String baseUrl;

  static const _define = String.fromEnvironment('PASSKEY_API_BASE');

  String get _base => baseUrl.isNotEmpty ? baseUrl : _define;

  /// Indica se um servidor relying party está configurado.
  bool get isConfigured => _base.isNotEmpty;

  /// Verifica se o servidor tem WebAuthn/passkeys habilitados.
  Future<bool> enabled() async {
    if (!isConfigured) return false;
    try {
      final r = await _client
          .get(Uri.parse('$_base/api/passkey/health'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return false;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      return d['passkeys_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Inicia o cadastro: retorna (challengeId, optionsJson) para o autenticador.
  Future<({String challengeId, String optionsJson})> registerStart({
    required String username,
    required String displayName,
  }) async {
    final d = await _post('/api/passkey/register/start', {
      'username': username,
      'displayName': displayName,
    });
    final id = d['challengeId'] as String?;
    final options = d['options'];
    if (id == null || options == null) {
      throw PasskeyApiException(
          'Servidor não retornou as opções de registro.');
    }
    return (
      challengeId: id,
      optionsJson: options is String ? options : jsonEncode(options),
    );
  }

  /// Finaliza o cadastro entregando a credencial criada no dispositivo.
  Future<bool> registerFinish({
    required String challengeId,
    required String credentialJson,
  }) async {
    final d = await _post('/api/passkey/register/finish', {
      'challengeId': challengeId,
      'credential': jsonDecode(credentialJson),
    });
    return d['verified'] == true;
  }

  /// Inicia o login: retorna (challengeId, optionsJson).
  Future<({String challengeId, String optionsJson})> loginStart({
    required String username,
  }) async {
    final d = await _post('/api/passkey/login/start', {'username': username});
    final id = d['challengeId'] as String?;
    final options = d['options'];
    if (id == null || options == null) {
      throw PasskeyApiException('Servidor não retornou as opções de login.');
    }
    return (
      challengeId: id,
      optionsJson: options is String ? options : jsonEncode(options),
    );
  }

  /// Finaliza o login entregando a asserção assinada pelo dispositivo.
  Future<String> loginFinish({
    required String challengeId,
    required String credentialJson,
  }) async {
    final d = await _post('/api/passkey/login/finish', {
      'challengeId': challengeId,
      'credential': jsonDecode(credentialJson),
    });
    if (d['verified'] != true) {
      throw PasskeyApiException('Passkey não verificada pelo servidor.');
    }
    final username = d['username'] as String?;
    if (username == null || username.isEmpty) {
      throw PasskeyApiException('Servidor não identificou o usuário.');
    }
    return username;
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final res = await _client
        .post(
          Uri.parse('$_base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      String msg = 'Servidor de passkeys indisponível (${res.statusCode}).';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map && d['error'] is String) msg = d['error'] as String;
      } catch (_) {}
      throw PasskeyApiException(msg);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}

class PasskeyApiException implements Exception {
  PasskeyApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
