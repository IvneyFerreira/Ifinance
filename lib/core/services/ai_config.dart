import 'package:shared_preferences/shared_preferences.dart';

/// Configuração do servidor do Assessor IA (Opção B).
///
/// O app **já sai configurado de fábrica**: aponta por padrão para o servidor
/// público do IFinance, sem o usuário precisar colar nenhum endereço.
///
/// O endereço base da API é resolvido nesta ordem de prioridade:
///   1. **No próprio app** (Configurações → Assistente IA) — salvo em
///      SharedPreferences. Permite trocar de servidor SEM recompilar o APK.
///   2. **Compilação**: `--dart-define=ASSESSOR_API_BASE=https://...`
///      (sobrescreve o padrão de fábrica no build).
///   3. **Padrão de fábrica** ([defaultBaseUrl]) — embutido no app.
///
/// O `verifySsl` fica `true` por padrão; só é desativado pelo usuário em
/// cenários de teste com certificado self-signed.
class AiConfig {
  AiConfig._();

  static const _kBase = 'ifinance_ai_base_url';
  static const _kVerifySsl = 'ifinance_ai_verify_ssl';
  static const _kToken = 'ifinance_ai_token';

  /// Servidor público padrão do Assessor IA (de fábrica, já embutido no app).
  /// O usuário NÃO precisa colar nada — já vem pronto para usar.
  static const String defaultBaseUrl =
      'https://ifinance-assessor.onrender.com';

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

  /// `true` quando há um servidor configurado (app, compilação ou padrão).
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// `true` quando o app está usando o servidor público padrão de fábrica.
  static bool get isUsingDefault =>
      _override.isEmpty && compiledBaseUrl.isEmpty;

  /// Endereço base efetivo (sem barra final).
  ///
  /// Prioridade: app (usuário) > compilação > padrão de fábrica.
  static String get baseUrl {
    final raw = _override.isNotEmpty
        ? _override
        : (compiledBaseUrl.isNotEmpty ? compiledBaseUrl : defaultBaseUrl);
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
    return 'Servidor padrão IFinance';
  }
}
