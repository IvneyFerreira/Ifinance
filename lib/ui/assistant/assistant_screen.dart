import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';

/// IFinance Assessor (cap. 36-39): tela estilo chat. A IA NÃO calcula — ela explica
/// o resultado estruturado fornecido pelo FinanceEngine.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Msg {
  final String text;
  final bool fromUser;
  final String? calculation;
  _Msg(this.text, {this.fromUser = false, this.calculation});
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    _Msg('Olá. O que você quer entender sobre suas finanças hoje?'),
  ];

  static const _suggestions = [
    'Quanto posso gastar?',
    'Como termina meu mês?',
    'Onde estou gastando mais?',
    'Quanto tenho comprometido?',
    'Como está meu cartão?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final c = context.read<AppController>();
    final engine = c.engine;
    setState(() => _messages.add(_Msg(text, fromUser: true)));

    String answer;
    String? calc;
    final q = text.toLowerCase();

    if (q.contains('gastar') || q.contains('posso')) {
      final d = engine.assistantSafeToSpend();
      answer =
          'Hoje você tem ${_m(d['free'] as int)} livres com segurança até ${_date(d['until'] as DateTime)}. Isso já desconta compromissos e sua margem de segurança.';
      calc =
          'Saldo ${_m(d['available'] as int)} − Compromissos ${_m(d['committed'] as int)} − Margem ${_m(d['margin'] as int)} = ${_m(d['free'] as int)}';
    } else if (q.contains('mês') || q.contains('mes') || q.contains('termina')) {
      final d = engine.assistantMonthOutlook();
      answer =
          'Este mês você recebeu ${_m(d['income'] as int)} e gastou ${_m(d['expense'] as int)}. Resultado: ${_m(d['result'] as int)}. Projeção de fim de mês: ${_m(d['projectedEnd'] as int)}.';
    } else if (q.contains('onde') || q.contains('gastando') || q.contains('mais')) {
      final top = engine.assistantTopCategories(limit: 3);
      if (top.isEmpty) {
        answer = 'Ainda não há despesas registradas neste mês.';
      } else {
        answer = 'Onde você mais gastou: '
            '${top.map((e) => '${e.name} (${_m(e.amount)})').join(', ')}.';
      }
    } else if (q.contains('comprometido')) {
      final d = engine.assistantCommitted();
      answer =
          'Você tem ${_m(d['committedMonth'] as int)} comprometidos até o fim do mês.';
    } else if (q.contains('cartão') || q.contains('cartao')) {
      final d = engine.assistantCardStatus();
      final cards = (d['cards'] as List);
      if (cards.isEmpty) {
        answer = 'Você ainda não cadastrou cartões.';
      } else {
        answer = cards
            .map((x) => '${x['name']}: fatura atual ${_m(x['currentInvoice'] as int)}, disponível ${_m(x['available'] as int)}')
            .join('. ');
      }
    } else {
      answer =
          'Posso te ajudar com: quanto você pode gastar, como termina o mês, onde está gastando mais, quanto está comprometido e como está seu cartão.';
    }

    setState(() => _messages.add(_Msg(answer, calculation: calc)));
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  static String _m(int cents) {
    final s = (cents / 100).toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'R\$ $intPart,${parts[1]}';
  }

  static String _date(DateTime d) => '${d.day}/${d.month}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IFinance Assessor')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(context, _messages[i]),
            ),
          ),
          if (_messages.length <= 1) _suggestionsRow(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, _Msg m) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = m.fromUser
        ? AppColors.emerald
        : (isDark ? AppColors.darkCard : AppColors.lightCard);
    final textColor = m.fromUser ? Colors.white : t.bodyMedium?.color;
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: m.fromUser
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text, style: t.bodyMedium?.copyWith(color: textColor, height: 1.4)),
            if (m.calculation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        size: 15, color: AppColors.emerald),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Ver cálculo: ${m.calculation}',
                          style: t.bodySmall?.copyWith(fontSize: 11, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestionsRow() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _suggestions.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () => _send(s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: _send,
                decoration: const InputDecoration(
                  hintText: 'Pergunte algo...',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.emerald,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  _send(_input.text);
                  _input.clear();
                },
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
