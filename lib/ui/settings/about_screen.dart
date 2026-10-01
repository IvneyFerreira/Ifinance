import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/components.dart';

/// Tela "Sobre e Ajuda": informações do app e perguntas frequentes.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre e Ajuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'IFinance',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text('Versão $appVersion', style: t.bodySmall),
                const SizedBox(height: 4),
                Text(
                  'Controle financeiro na palma da sua mão.',
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'By Ivoney Ferreira',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Como funciona'),
          FinancialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O IFinance responde a quatro perguntas centrais:',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 10),
                _bullet(context, 'Quanto eu tenho?'),
                _bullet(context, 'Quanto está comprometido?'),
                _bullet(context, 'Quanto está realmente livre?'),
                _bullet(context, 'Como eu vou terminar o mês?'),
                const SizedBox(height: 10),
                Text(
                  'Todos os valores são tratados em centavos (inteiros), '
                  'evitando erros de arredondamento. Compras no cartão contam '
                  'como despesa na data da compra, e o pagamento da fatura é '
                  'movimentação de caixa — sem dupla contagem.',
                  style: t.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Perguntas frequentes'),
          _faq(
            context,
            'Como registro uma despesa?',
            'Toque no botão + e escolha Despesa, ou use o atalho rápido na Home.',
          ),
          _faq(
            context,
            'Como funciona a IA (Assessor)?',
            'O Assessor é focado em finanças: ajuda com despesas, entradas, saldo, cartões e orçamento. Ele recusa perguntas fora desse escopo.',
          ),
          _faq(
            context,
            'Meus dados ficam seguros?',
            'Sim. Tudo é guardado no seu dispositivo (banco local). Você pode fazer backup, exportar CSV/PDF e restaurar quando quiser.',
          ),
          _faq(
            context,
            'Como proteger o app?',
            'Em Configurações → Segurança você ativa o bloqueio por PIN, '
                'o desbloqueio por biometria e a autenticação em 2 fatores.',
          ),
          _faq(
            context,
            'Como recebo lembretes de contas?',
            'Em Configurações → Lembretes, ative os avisos e escolha a '
                'antecedência. As notificações aparecem no sino e no sistema.',
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Sobre'),
          FinancialCard(
            child: Column(
              children: [
                _row(context, 'Aplicativo', 'IFinance'),
                const Divider(height: 20),
                _row(context, 'Versão', appVersion),
                const Divider(height: 20),
                _row(context, 'Plataformas', 'Android · Web/PWA'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '© 2026 IFinance',
              style: t.bodySmall?.copyWith(color: AppColors.gray400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.emerald,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _faq(BuildContext context, String q, String a) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FinancialCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          iconColor: AppColors.emerald,
          title: Text(
            q,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a, style: t.bodySmall?.copyWith(height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
