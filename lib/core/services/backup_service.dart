import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../db/hive_db.dart';

/// Metadados de um snapshot local (sem o conteúdo, para listagem leve).
class BackupSnapshotInfo {
  final String id;
  final DateTime createdAt;
  final String reason; // 'auto' | 'manual' | 'pre-restore'
  final int recordCount;
  final int payloadBytes;

  const BackupSnapshotInfo({
    required this.id,
    required this.createdAt,
    required this.reason,
    required this.recordCount,
    required this.payloadBytes,
  });

  String get label => switch (reason) {
        'manual' => 'Salvo manualmente',
        'pre-restore' => 'Antes de restaurar',
        _ => 'Automático',
      };
}

/// Snapshots automáticos de segurança (cap. 73).
///
/// Motivação: no Web (PWA), tanto o IndexedDB (Hive) quanto o localStorage
/// (SharedPreferences) PODEM ser limpos pelo navegador/SO sob pressão de
/// armazenamento ou durante uma atualização. No Android o espaço de dados é
/// preservado entre atualizações, mas mantemos o mesmo mecanismo por segurança.
///
/// Estratégia:
/// - Guardamos as últimas [maxSnapshots] fotografias completas do banco do
///   usuário numa caixa Hive dedicada (`backup_snapshots`);
/// - Só gravamos quando o conteúdo MUDOU (dedupe por hash) para não gastar
///   espaço a cada frame;
/// - Se um dia o banco voltar vazio, o usuário recupera tudo em 1 toque
///   sem depender de download nem de arquivo externo.
class BackupService {
  BackupService._();

  static const int maxSnapshots = 5;

  static Box<Map> get _box => Hive.box<Map>(Db.backups);

  /// Cria (ou ignora, se idêntico ao último) um snapshot do banco atual.
  /// Retorna o id do snapshot gravado, ou null se nada mudou / vazio / erro.
  static Future<String?> snapshotNow({
    required String userId,
    required Map<String, dynamic> data,
    required String reason,
    bool force = false,
  }) async {
    if (userId.isEmpty) return null;
    // Nunca sobrescreve uma base boa com uma base vazia.
    if (!force && _isEffectivelyEmpty(data)) return null;

    try {
      final payload = jsonEncode(data);
      final entry = <String, dynamic>{
        'userId': userId,
        'reason': reason,
        'createdAt': DateTime.now().toIso8601String(),
        'recordCount': _countRecords(data),
        'payload': payload,
        'bytes': payload.length,
        'hash': _hash(payload),
      };

      // Dedupe: se o último snapshot do usuário tem o mesmo conteúdo, pula.
      if (!force) {
        final last = listFor(userId).where((s) => s.reason != 'pre-restore');
        if (last.isNotEmpty) {
          final lastRaw = _rowFor(last.first.id);
          if (lastRaw != null && lastRaw['hash'] == entry['hash']) return null;
        }
      }

      final id = '${DateTime.now().microsecondsSinceEpoch}';
      await _box.put(id, Map<String, dynamic>.from(entry)..['id'] = id);
      await _prune(userId);
      return id;
    } catch (e) {
      if (kDebugMode) debugPrint('[BackupService] snapshot falhou: $e');
      return null;
    }
  }

  /// Snapshots do usuário, mais recentes primeiro.
  static List<BackupSnapshotInfo> listFor(String userId) {
    final list = <BackupSnapshotInfo>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final m = raw.map((k, v) => MapEntry(k.toString(), v));
      if (m['userId'] != userId) continue;
      list.add(BackupSnapshotInfo(
        id: (m['id'] ?? key).toString(),
        createdAt: DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        reason: (m['reason'] as String?) ?? 'auto',
        recordCount: (m['recordCount'] as num?)?.toInt() ?? 0,
        payloadBytes: (m['bytes'] as num?)?.toInt() ?? 0,
      ));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Conteúdo (JSON decodificado) de um snapshot, ou null.
  static Map<String, dynamic>? read(String snapshotId) {
    final raw = _rowFor(snapshotId);
    if (raw == null) return null;
    final payload = raw['payload'] as String?;
    if (payload == null) return null;
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String snapshotId) async {
    await _box.delete(snapshotId);
  }

  static Future<void> clearFor(String userId) async {
    final ids = listFor(userId).map((s) => s.id).toList();
    for (final id in ids) {
      await _box.delete(id);
    }
  }

  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _rowFor(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Mantém apenas os [maxSnapshots] mais recentes (preserva 'pre-restore').
  static Future<void> _prune(String userId) async {
    final list = listFor(userId);
    final removable = list.where((s) => s.reason != 'pre-restore').toList();
    if (removable.length <= maxSnapshots) return;
    for (final s in removable.sublist(maxSnapshots)) {
      await _box.delete(s.id);
    }
  }

  static bool _isEffectivelyEmpty(Map<String, dynamic> data) =>
      isEffectivelyEmpty(data);

  /// `true` quando o snapshot não contém dados financeiros relevantes.
  static bool isEffectivelyEmpty(Map<String, dynamic> data) {
    const keys = [
      'accounts', 'transactions', 'cards', 'budgets', 'goals', 'categories',
      'recurringRules', 'purchases', 'installments', 'subscriptions',
      'contributions', 'assets', 'liabilities',
    ];
    for (final k in keys) {
      final v = data[k];
      if (v is List && v.isNotEmpty) return false;
    }
    return true;
  }

  static int _countRecords(Map<String, dynamic> data) {
    var n = 0;
    for (final v in data.values) {
      if (v is List) n += v.length;
    }
    return n;
  }

  static String _hash(String s) {
    // Hash simples e estável (não criptográfico) só para dedupe.
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return '${h}_${s.length}_${_fnv(s)}';
  }

  static int _fnv(String s) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Espaço aproximado ocupado pelos snapshots de um usuário (bytes).
  static int storageUsedFor(String userId) =>
      listFor(userId).fold(0, (s, e) => s + e.payloadBytes);

  static int get maxSnapshotsConfigured => maxSnapshots;
}
