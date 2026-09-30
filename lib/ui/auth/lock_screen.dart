import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';

/// Bloqueio do app por PIN (cap. 71 — segurança).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = context.read<AppController>();
      if (!c.biometricEnabled) return;
      final avail = await c.biometricAvailable();
      if (mounted) setState(() => _biometricAvailable = avail);
      // Tenta desbloquear automaticamente com biometria ao abrir.
      if (avail) await _biometric();
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final c = context.read<AppController>();
    if (c.verifyPin(_pin.text)) {
      c.unlockWithPin(_pin.text);
    } else {
      setState(() => _error = 'PIN incorreto. Tente novamente.');
      _pin.clear();
    }
  }

  Future<void> _biometric() async {
    final c = context.read<AppController>();
    final ok = await c.unlockWithBiometric();
    if (!ok && mounted) {
      setState(() => _error = 'Biometria não reconhecida. Use o PIN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text('IFinance bloqueado',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Digite seu PIN para continuar', style: t.bodySmall),
              const SizedBox(height: 26),
              TextField(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
                style: t.headlineMedium?.copyWith(letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _error,
                  hintText: '••••',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Desbloquear'),
                ),
              ),
              if (_biometricAvailable) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _biometric,
                  icon: const Icon(Icons.fingerprint, color: AppColors.emerald),
                  label: const Text('Usar biometria',
                      style: TextStyle(color: AppColors.emerald)),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.read<AppController>().logout(),
                child: const Text('Sair da conta',
                    style: TextStyle(color: AppColors.negative)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
