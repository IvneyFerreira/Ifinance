
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/passkey_service.dart';
import '../../core/services/passkey_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Tela de autenticação (cap. 52): Login / Cadastro / Recuperação de senha.
/// Somente e-mail e senha oficiais — sem contas demo ou acesso anônimo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { login, register, forgot }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.login;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _totp = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _needTotp = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final controller = context.read<AppController>();
    try {
      switch (_mode) {
        case _Mode.login:
          final done = await controller.login(
            email: _email.text,
            password: _password.text,
          );
          if (!done && mounted) {
            // 2FA habilitado: pede o segundo fator.
            setState(() => _needTotp = true);
          }
          break;
        case _Mode.register:
          if (_password.text != _confirm.text) {
            throw AuthException('As senhas não coincidem.');
          }
          await controller.register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
          break;
        case _Mode.forgot:
          await controller.resetPassword(
            email: _email.text,
            newPassword: _password.text,
          );
          if (mounted) {
            showToast(context, 'Senha redefinida com sucesso. Faça login.');
            setState(() => _mode = _Mode.login);
          }
          break;
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Não foi possível concluir. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitTotp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await context.read<AppController>().confirmTwoFactor(_totp.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = 'Código inválido. Tente novamente.');
      _totp.clear();
    }
  }

  /// Login sem senha por passkey (WebAuthn).
  Future<void> _loginPasskey() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Informe o e-mail da conta para usar a passkey.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final controller = context.read<AppController>();
    try {
      final done = await controller.loginWithPasskey(_email.text);
      if (!done && mounted) setState(() => _needTotp = true);
    } on PasskeyFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PasskeyApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar com a passkey.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelTotp() {
    context.read<AppController>().cancelTwoFactor();
    setState(() {
      _needTotp = false;
      _error = null;
      _totp.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needTotp) return _buildTotp();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text('iF',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IFinance',
                              style: t.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Personal Financial Command Center',
                              style: t.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(_title(), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_subtitle(), style: t.bodyMedium),
                  const SizedBox(height: 24),
                  if (_mode == _Mode.register) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: _mode == _Mode.forgot
                          ? 'Nova senha'
                          : 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_mode == _Mode.register) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.negative.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.negative, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!,
                                style: t.bodySmall
                                    ?.copyWith(color: AppColors.negative)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_buttonLabel()),
                  ),
                  if (_mode == _Mode.login && context.watch<AppController>().passkeysConfigured) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _loginPasskey,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Entrar com passkey'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotp() {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.verified_user_outlined,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text('Verificação em 2 etapas',
                      style:
                          t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Abra seu app autenticador e digite o código de 6 dígitos.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _totp,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(letterSpacing: 8),
                    onSubmitted: (_) => _submitTotp(),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submitTotp,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirmar'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : _cancelTotp,
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _title() => switch (_mode) {        _Mode.login => 'Bem-vindo de volta',
        _Mode.register => 'Criar sua conta',
        _Mode.forgot => 'Recuperar senha',
      };

  String _subtitle() => switch (_mode) {
        _Mode.login => 'Acesse para colocar sua vida financeira sob controle.',
        _Mode.register => 'Comece agora a organizar seu dinheiro.',
        _Mode.forgot => 'Informe seu e-mail e defina uma nova senha.',
      };

  String _buttonLabel() => switch (_mode) {
        _Mode.login => 'Entrar',
        _Mode.register => 'Criar conta',
        _Mode.forgot => 'Redefinir senha',
      };

  Widget _footer() {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        if (_mode == _Mode.login) ...[
          TextButton(
            onPressed: () => setState(() {
              _mode = _Mode.forgot;
              _error = null;
            }),
            child: const Text('Esqueci minha senha'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ainda não tem conta?', style: t.bodySmall),
              TextButton(
                onPressed: () => setState(() {
                  _mode = _Mode.register;
                  _error = null;
                }),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ] else
          TextButton(
            onPressed: () => setState(() {
              _mode = _Mode.login;
              _error = null;
            }),
            child: const Text('Voltar para o login'),
          ),
      ],
    );
  }
}
