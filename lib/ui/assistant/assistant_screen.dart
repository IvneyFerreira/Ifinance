import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/assessor_api.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../shell/app_drawer.dart';

/// IFinance Assessor (cap. 36-39): assistente FINANCEIRO com IA real.
///
/// A IA recebe um CONTEXTO FINANCEIRO (montado pelo FinanceEngine) com despesas,
/// entradas, orçamentos, cartões e assinaturas — e ajuda o usuário SOMENTE com a
/// vida financeira dele. Assuntos aleatórios são recusados.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Msg {
  final String text;
  final bool fromUser;
  final bool isError;
  final bool loading;
  _Msg(
    this.text, {
    this.fromUser = false,
    this.isError = false,
    this.loading = false,
  });
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _api = AssessorApi();

  bool? _aiEnabled; // null = verificando
  bool _sending = false;

  final List<_Msg> _messages = [
    _Msg(
      'Olá! Sou seu Assessor Financeiro. Posso te ajudar com despesas, entradas, '
      'orçamentos, cartões e assinaturas — sempre com base nos seus dados reais.\n\n'
      'Pergunte, por exemplo: "Onde estou gastando mais?" ou "Quanto entrou este mês?".',
    ),
  ];

  static const _suggestions = [
    'Onde estou gastando mais?',
    'Quanto entrou este mês?',
    'Estou dentro do orçamento?',
    'Como estão minhas assinaturas?',
    'Como reduzir minhas despesas?',
  ];

  @override
  void initState() {
    super.initState();
    _checkAi();
  }

  Future<void> _checkAi() async {
    final ok = await _api.health();
    if (mounted) setState(() => _aiEnabled = ok);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    final c = context.read<AppController>();

    // Histórico ANTES de adicionar a pergunta atual (o servidor já a envia).
    final history = _messages
        .where((m) => !m.loading && !m.isError)
        .map((m) => {'text': m.text, 'fromUser': m.fromUser})
        .toList();

    setState(() {
      _messages.add(_Msg(q, fromUser: true));
      _messages.add(_Msg('Analisando suas finanças...', loading: true));
      _sending = true;
    });
    _scrollToEnd();

    final context_ = FinancialContext.build(c.engine, c.budgets);

    String answer;
    bool error = false;
    try {
      answer = await _api.ask(question: q, context: context_, history: history);
    } on AssessorException catch (e) {
      answer = 'Não consegui falar com a IA agora. ${e.message}';
      error = true;
    } catch (_) {
      answer =
          'Não consegui falar com a IA agora. Verifique sua conexão e tente novamente.';
      error = true;
    }

    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.loading);
      _messages.add(_Msg(answer, isError: error));
      _sending = false;
      _aiEnabled = !error || _aiEnabled != false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: const Text('IFinance Assessor'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _aiEnabled == true
                  ? 'IA financeira ativa • foco em despesas e entradas'
                  : _aiEnabled == false
                  ? 'IA indisponível no momento'
                  : 'Conectando à IA...',
              style: TextStyle(
                fontSize: 11.5,
                color: _aiEnabled == true
                    ? AppColors.emerald
                    : AppColors.gray400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
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
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: m.fromUser
              ? null
              : Border.all(
                  color: m.isError
                      ? AppColors.negativeSoft
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
        ),
        child: m.loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    m.text,
                    style: t.bodySmall?.copyWith(color: AppColors.gray400),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!m.fromUser) ...[
                    const CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.emerald,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      m.text,
                      style: t.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.42,
                      ),
                    ),
                  ),
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
    final disabled = _sending || _aiEnabled == false;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: _sending ? null : _send,
                decoration: const InputDecoration(
                  hintText: 'Pergunte sobre suas finanças...',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: disabled ? AppColors.gray400 : AppColors.emerald,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: disabled
                    ? null
                    : () {
                        final txt = _input.text;
                        _input.clear();
                        _send(txt);
                      },
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
