import 'package:shared_preferences/shared_preferences.dart';

/// Configuração do servidor do Assessor IA (Opção B).
///
/// O endereço base da API pode ser definido de três formas, em ordem de
/// prioridade:
///   1. **No próprio app** (Configurações → Assistente IA) — salvo em
///      SharedPreferences. Permite trocar de servidor SEM recompilar o APK.
///   2. **Compilação**: `--dart-define=ASSESSOR_API_BASE=https://...`
///      (valor padrão embutido no build).
///   3. **Mesma origem**: vazio (usa o host que serve o app web / preview).
///
/// O `verifySsl` fica `true` por padrão; só é desativado pelo usuário em
/// cenários de teste com certificado self-signed.
class AiConfig {
  AiConfig._();

  static const _kBase = 'ifinance_ai_base_url';
  static const _kVerifySsl = 'ifinance_ai_verify_ssl';
  static const _kToken = 'ifinance_ai_token';

  /// Valor embutido no build via --dart-define (pode ser vazio).
  static const String compiledBaseUrl =
      String.fromEnvironment('ASSESSOR_API_BASE');

  /// Token embutido no build via --dart-define (opcional).
  static const String compiledToken =
      String.fromEnvironment('ASSESSOR_API_TOKEN');

  static String _override = '';
  static String _token = '';
  static bool _verifySsl = true;
  static bool _loaded = false;

  /// `true` quando há um servidor configurado (app ou compilação).
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Endereço base efetivo (sem barra final).
  static String get baseUrl {
    final raw = _override.isNotEmpty ? _override : compiledBaseUrl;
    return raw.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Endereço definido pelo usuário (vazio se estiver usando o padrão).
  static String get userBaseUrl => _override;

  /// Token de acesso (opcional) enviado no cabeçalho X-IFinance-Token.
  static String get token => _token.isNotEmpty ? _token : compiledToken;

  /// Se o app deve validar o certificado TLS do servidor (padrão: true).
  static bool get verifySsl => _verifySsl;

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _override = (prefs.getString(_kBase) ?? '').trim();
    _token = (prefs.getString(_kToken) ?? '').trim();
    _verifySsl = prefs.getBool(_kVerifySsl) ?? true;
    _loaded = true;
  }

  /// Define (ou limpa, com `null`/vazio) o endereço do servidor.
  static Future<void> save({
    String? baseUrl,
    String? token,
    bool? verifySsl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      _override = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      if (_override.isEmpty) {
        await prefs.remove(_kBase);
      } else {
        await prefs.setString(_kBase, _override);
      }
    }
    if (token != null) {
      _token = token.trim();
      if (_token.isEmpty) {
        await prefs.remove(_kToken);
      } else {
        await prefs.setString(_kToken, _token);
      }
    }
    if (verifySsl != null) {
      _verifySsl = verifySsl;
      await prefs.setBool(_kVerifySsl, verifySsl);
    }
    _loaded = true;
  }

  /// Descrição curta do modo atual, para exibir na UI.
  static String describe() {
    if (_override.isNotEmpty) return 'Personalizado';
    if (compiledBaseUrl.isNotEmpty) return 'Embutido no app';
    return 'Mesma origem (não configurado)';
  }
}
