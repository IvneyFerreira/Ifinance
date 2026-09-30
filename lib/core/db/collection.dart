import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Coleção genérica persistida em Hive.
///
/// Cap. 53 (Multiusuário): TODA leitura pode ser filtrada por userId.
/// Nenhuma consulta deve depender apenas do id do registro.
///
/// RESILIÊNCIA (cap. 73): um registro corrompido/legado NÃO pode derrubar a
/// leitura da coleção inteira. Se o `fromMap` de uma linha falhar, ela é
/// ignorada (com log) e as demais continuam disponíveis — evitando que o app
/// apareça "sem dados" por causa de uma única entrada inválida.
class Collection<T> {
  final String boxName;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;
  final String Function(T) idOf;
  final String Function(T)? userIdOf;

  /// Última vez que um registro precisou ser descartado por erro de leitura.
  static final Map<String, int> droppedCounts = {};

  Collection({
    required this.boxName,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
    this.userIdOf,
  });

  Box<Map> get _box => Hive.box<Map>(boxName);

  List<T> all() {
    final result = <T>[];
    var dropped = 0;
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        result.add(fromMap(_normalize(raw)));
      } catch (e) {
        dropped++;
        if (kDebugMode) {
          debugPrint('[Collection:$boxName] registro ignorado '
              '(id=$key): $e');
        }
      }
    }
    if (dropped > 0) {
      droppedCounts[boxName] = (droppedCounts[boxName] ?? 0) + dropped;
    }
    return result;
  }

  List<T> byUser(String userId) {
    if (userIdOf == null) return all();
    return all().where((e) => userIdOf!(e) == userId).toList();
  }

  T? findById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      return fromMap(_normalize(raw));
    } catch (e) {
      if (kDebugMode) debugPrint('[Collection:$boxName] findById($id): $e');
      return null;
    }
  }

  Future<void> put(T item) async {
    await _box.put(idOf(item), toMap(item));
  }

  Future<void> putAll(List<T> items) async {
    final map = {for (final it in items) idOf(it): toMap(it)};
    await _box.putAll(map);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearUser(String userId) async {
    if (userIdOf == null) return;
    final keys = byUser(userId).map(idOf).toList();
    for (final k in keys) {
      await _box.delete(k);
    }
  }

  Future<void> clear() async => _box.clear();

  static Map<String, dynamic> _normalize(Map raw) =>
      raw.map((key, value) => MapEntry(key.toString(), value));
}
