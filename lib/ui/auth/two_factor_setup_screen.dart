import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../widgets/qr_view.dart';

/// Configuração de 2FA por app autenticador (TOTP) — cap. 71.
///
/// Fluxo: mostra o segredo (QR + chave) e exige um código válido antes de
/// ativar, garantindo que o usuário configurou o autenticador corretamente.
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  late String _secret;
  late String _uri;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final setup = context.read<AppController>().beginTwoFactorSetup();
    _secret = setup.secret;
    _uri = setup.uri;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok =
        await context.read<AppController>().enableTwoFactor(_secret, _code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showToast(context, '2FA ativado com sucesso.');
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Código inválido. Verifique o app autenticador.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Autenticação em 2 fatores')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
        children: [
          Text(
            '1. Escaneie o QR Code no seu app autenticador '
            '(Google Authenticator, Authy, 1Password...).',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          Center(child: QrView(data: _uri, size: 210)),
          const SizedBox(height: 18),
          Text('2. Ou digite a chave manualmente:', style: t.bodyMedium),
          const SizedBox(height: 8),
          FinancialCard(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _secret,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar chave',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _secret));
                    if (context.mounted) {
                      showToast(context, 'Chave copiada.');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('3. Informe o código de 6 dígitos gerado:', style: t.bodyMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            autofocus: false,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Ativar 2FA'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O segredo fica apenas no seu dispositivo. Guarde-o com segurança.',
                  style: t.bodySmall?.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
