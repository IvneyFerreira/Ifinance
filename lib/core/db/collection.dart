import 'package:hive_flutter/hive_flutter.dart';

/// Coleção genérica persistida em Hive.
///
/// Cap. 53 (Multiusuário): TODA leitura pode ser filtrada por userId.
/// Nenhuma consulta deve depender apenas do id do registro.
class Collection<T> {
  final String boxName;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;
  final String Function(T) idOf;
  final String Function(T)? userIdOf;

  Collection({
    required this.boxName,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
    this.userIdOf,
  });

  Box<Map> get _box => Hive.box<Map>(boxName);

  List<T> all() =>
      _box.values.map((e) => fromMap(_normalize(e))).toList();

  List<T> byUser(String userId) {
    if (userIdOf == null) return all();
    return all().where((e) => userIdOf!(e) == userId).toList();
  }

  T? findById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return fromMap(_normalize(raw));
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
