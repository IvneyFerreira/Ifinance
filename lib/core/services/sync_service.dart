import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_config.dart';
import 'http_client_factory.dart';

/// Metadados do backup na nuvem (para exibir "última sincronização").
class CloudBackupInfo {
  final bool exists;
  final DateTime? updatedAt;
  final int sizeBytes;
  const CloudBackupInfo({
    required this.exists,
    this.updatedAt,
    this.sizeBytes = 0,
  });

  static const empty = CloudBackupInfo(exists: false);

  String get sizeLabel {
    if (sizeBytes <= 0) return '—';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Cliente do **backup automático na nuvem** (cap. 73).
///
/// Conversa com os endpoints `/api/sync/*` do servidor IFinance (o mesmo do
/// Assessor IA). O conteúdo enviado é SEMPRE o envelope cifrado produzido por
/// [SyncCrypto] — o servidor jamais vê os dados em claro.
///
/// - [info]  → consulta se já existe backup para a conta;
/// - [save]  → grava/substitui o backup (idempotente por conta);
/// - [load]  → baixa o envelope para restauração.
class SyncService {
  final String baseUrl;
  final http.Client _client;

  SyncService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? AiConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? createDefaultClient();

  bool get isConfigured => baseUrl.isNotEmpty;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AiConfig.token.isNotEmpty) 'X-IFinance-Token': AiConfig.token,
      };

  /// `true` quando o servidor tem o módulo de backup disponível.
  Future<bool> serverAvailable() async {
    if (!isConfigured) return false;
    try {
      final r = await _client
          .get(_uri('/api/sync/health'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return j['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Consulta os metadados do backup da conta (sem baixar o conteúdo).
  Future<CloudBackupInfo> info(String accountId) async {
    if (!isConfigured) return CloudBackupInfo.empty;
    try {
      final r = await _client
          .get(_uri('/api/sync/info?accountId=$accountId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return CloudBackupInfo.empty;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return CloudBackupInfo(
        exists: j['exists'] == true,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String),
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return CloudBackupInfo.empty;
    }
  }

  /// Envia (cria/substitui) o backup cifrado da conta. Retorna `true` se ok.
  Future<bool> save({
    required String accountId,
    required Map<String, dynamic> envelope,
  }) async {
    if (!isConfigured) return false;
    try {
      final r = await _client
          .post(
            _uri('/api/sync/save'),
            headers: _headers,
            body: jsonEncode({'accountId': accountId, 'envelope': envelope}),
          )
          .timeout(const Duration(seconds: 30));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Baixa o envelope cifrado da conta, ou `null` se não existir/erro.
  Future<Map<String, dynamic>?> load(String accountId) async {
    if (!isConfigured) return null;
    try {
      final r = await _client
          .get(_uri('/api/sync/load?accountId=$accountId'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final env = j['envelope'];
      if (env is Map) return Map<String, dynamic>.from(env);
      return null;
    } catch (_) {
      return null;
    }
  }
}
