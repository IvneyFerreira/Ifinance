import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/statement_importer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import '../shell/quick_add.dart';

/// Importação de extrato bancário (cap. 15/16): cole o CSV/OFX do banco,
/// confira a prévia categorizada e importe para uma conta.
class StatementImportScreen extends StatefulWidget {
  const StatementImportScreen({super.key});

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  final _content = TextEditingController();
  String? _accountId;
  List<ImportedRow> _rows = const [];
  bool _asPending = false;
  bool _autoCategory = true;
  bool _saving = false;
  bool _parsed = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppController>();
    if (c.accounts.isNotEmpty) _accountId = c.accounts.first.id;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final t = Theme.of(context).textTheme;
    final income = _rows.where((r) => r.isIncome).length;
    final expense = _rows.where((r) => !r.isIncome).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Importar extrato')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          FinancialCard(
            color: AppColors.info.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Formatos aceitos: CSV (separado por ; ou ,) e OFX. Cole o conteúdo do arquivo do seu banco abaixo.',
                    style: t.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Conta de destino',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (c.accounts.isEmpty)
            const Text('Cadastre uma conta primeiro.')
          else
            AccountPicker(
              accounts: c.accounts,
              selectedId: _accountId,
              onSelected: (id) => setState(() => _accountId = id),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Conteúdo do extrato',
                    style:
                        t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Colar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _content,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Data;Descrição;Valor\n12/03/2026;Mercado Extra;-240,00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _parse,
            icon: const Icon(Icons.search),
            label: const Text('Analisar extrato'),
          ),
          if (_parsed) ...[
            const SizedBox(height: 20),
            if (_rows.isEmpty)
              const EmptyState(
                icon: Icons.find_in_page_outlined,
                title: 'Nenhum lançamento reconhecido',
                message:
                    'Verifique se o conteúdo está no formato do banco (CSV ou OFX).',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _stat(context, 'Lançamentos', '${_rows.length}',
                        AppColors.emerald),
                  ),
                  Expanded(
                    child: _stat(context, 'Entradas', '$income', AppColors.positive),
                  ),
                  Expanded(
                    child: _stat(context, 'Saídas', '$expense', AppColors.negative),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Categorizar automaticamente'),
                subtitle: const Text('Usa palavras-chave da descrição'),
                value: _autoCategory,
                onChanged: (v) => setState(() => _autoCategory = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Importar como pendente'),
                subtitle: const Text(
                    'Desligado: marca como concluído (recomendado para extratos passados)'),
                value: _asPending,
                onChanged: (v) => setState(() => _asPending = v),
              ),
              const SizedBox(height: 10),
              Text('Prévia',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._rows.take(50).map((r) => _previewTile(context, c, r)),
              if (_rows.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('e mais ${_rows.length - 50} lançamentos...',
                      style: t.bodySmall),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving || _accountId == null ? null : _import,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_done),
                label: Text('Importar ${_rows.length} lançamentos'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _previewTile(BuildContext ctx, AppController c, ImportedRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(DateHelpers.dayMonth.format(r.date),
                style: Theme.of(ctx).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(r.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodyMedium),
          ),
          MoneyDisplay(r.amountCents, fontSize: 13, colorize: true),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && mounted) {
      setState(() => _content.text = data!.text!);
    }
  }

  void _parse() {
    final rows = StatementImporter.parse(_content.text);
    setState(() {
      _rows = rows;
      _parsed = true;
    });
  }

  Future<void> _import() async {
    if (_accountId == null) return;
    setState(() => _saving = true);
    try {
      final count = await context.read<AppController>().importStatements(
            rows: _rows,
            accountId: _accountId!,
            asPending: _asPending,
            autoCategory: _autoCategory,
          );
      if (mounted) {
        showToast(context, '$count lançamentos importados.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não foi possível importar o extrato.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
