import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import '../db/repository.dart';

/// Serviço de autenticação (cap. 52 / 71).
/// - Hash seguro de senha (PBKDF2-like: salt aleatório + SHA-256 iterado);
/// - Sessão local persistida via SharedPreferences;
/// - Isolamento de dados por usuário (cap. 53).
///
/// Observação: como o ambiente é offline-first (Hive local), a "sessão"
/// é o último usuário autenticado. Em produção nativa o mesmo contrato
/// de serviço seria preservado.
class AuthService {
  AuthService(this._repo);

  final Repository _repo;

  static const int _iterations = 12000;

  AppUser? _current;

  AppUser? get currentUser => _current;
  bool get isAuthenticated => _current != null;

  /// Deriva o hash da senha.
  String _hash(String password, String salt) {
    var bytes = utf8.encode('$salt::$password');
    Digest digest = sha256.convert(bytes);
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
    }
    return digest.toString();
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String? validateEmail(String email) {
    final re = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]+$');
    if (!re.hasMatch(email.trim())) return 'Informe um e-mail válido.';
    return null;
  }

  String? validatePassword(String password) {
    if (password.length < 6) {
      return 'A senha deve ter ao menos 6 caracteres.';
    }
    return null;
  }

  bool emailExists(String email) => _repo.users
      .all()
      .any((u) => !u.deleted && u.email.toLowerCase() == email.trim().toLowerCase());

  /// Cadastro de um novo usuário (cap. 51/52).
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final emailErr = validateEmail(email);
    if (emailErr != null) throw AuthException(emailErr);
    final passErr = validatePassword(password);
    if (passErr != null) throw AuthException(passErr);
    if (emailExists(email)) {
      throw AuthException('Este e-mail já está cadastrado.');
    }

    final now = DateTime.now();
    final salt = _generateSalt();
    final user = AppUser(
      id: _repo.newId(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: _hash(password, salt),
      passwordSalt: salt,
      emailVerified: false,
      onboardingCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.users.put(user);
    await _repo.settings.put(UserSettings(userId: user.id));
    await _repo.log(user.id, 'register', 'User', entityId: user.id);
    _current = user;
    return user;
  }

  /// Login com e-mail/senha.
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final match = _repo.users.all().where(
          (u) => !u.deleted && u.email.toLowerCase() == normalized,
        );
    if (match.isEmpty) {
      throw AuthException('E-mail ou senha incorretos.');
    }
    final user = match.first;
    final hash = _hash(password, user.passwordSalt);
    if (hash != user.passwordHash) {
      throw AuthException('E-mail ou senha incorretos.');
    }
    _current = user;
    await _repo.log(user.id, 'login', 'User', entityId: user.id);
    return user;
  }

  /// Recuperação de senha: valida e-mail e redefine.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final passErr = validatePassword(newPassword);
    if (passErr != null) throw AuthException(passErr);
    final normalized = email.trim().toLowerCase();
    final match = _repo.users
        .all()
        .where((u) => !u.deleted && u.email.toLowerCase() == normalized)
        .toList();
    if (match.isEmpty) {
      throw AuthException('Nenhuma conta encontrada para este e-mail.');
    }
    final user = match.first;
    final salt = _generateSalt();
    final updated = user.copyWith(
      passwordSalt: salt,
      passwordHash: _hash(newPassword, salt),
      updatedAt: DateTime.now(),
    );
    await _repo.users.put(updated);
    await _repo.log(user.id, 'reset_password', 'User', entityId: user.id);
  }

  /// Verificação de e-mail (simulada localmente).
  Future<void> verifyEmail() async {
    if (_current == null) return;
    final updated =
        _current!.copyWith(emailVerified: true, updatedAt: DateTime.now());
    await _repo.users.put(updated);
    _current = updated;
  }

  Future<void> completeOnboarding() async {
    if (_current == null) return;
    final updated =
        _current!.copyWith(onboardingCompleted: true, updatedAt: DateTime.now());
    await _repo.users.put(updated);
    _current = updated;
  }

  Future<void> updateProfile({String? name}) async {
    if (_current == null) return;
    final updated = _current!.copyWith(name: name, updatedAt: DateTime.now());
    await _repo.users.put(updated);
    _current = updated;
  }

  /// Exclusão de conta — remove dados financeiros do usuário (cap. 72).
  Future<void> deleteAccount() async {
    final user = _current;
    if (user == null) return;
    await _repo.accounts.clearUser(user.id);
    await _repo.transactions.clearUser(user.id);
    await _repo.categories.clearUser(user.id);
    await _repo.cards.clearUser(user.id);
    await _repo.purchases.clearUser(user.id);
    await _repo.installments.clearUser(user.id);
    await _repo.invoices.clearUser(user.id);
    await _repo.recurring.clearUser(user.id);
    await _repo.budgets.clearUser(user.id);
    await _repo.goals.clearUser(user.id);
    await _repo.contributions.clearUser(user.id);
    await _repo.assets.clearUser(user.id);
    await _repo.liabilities.clearUser(user.id);
    await _repo.subscriptions.clearUser(user.id);
    await _repo.notifications.clearUser(user.id);
    await _repo.users.delete(user.id);
    _current = null;
  }

  void logout() {
    _current = null;
  }

  /// Restaura sessão do usuário (último logado).
  void restoreSession(String userId) {
    final user = _repo.users.findById(userId);
    if (user != null && !user.deleted) _current = user;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
