import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import 'statement_import_screen.dart';

/// Importar / Exportar (cap. 42/43): backup completo (JSON), exportação em CSV
/// e restauração. Tudo local, sem enviar dados para fora.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          FinancialCard(
            color: AppColors.info.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seus dados são seus. O backup é gerado no seu dispositivo e você decide onde guardá-lo.',
                    style: t.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Backup e restauração'),
          _tile(
            context,
            icon: Icons.file_download_outlined,
            title: 'Gerar backup (JSON)',
            subtitle: 'Cópia completa de contas, movimentações, metas e mais',
            onTap: () => _exportJson(context),
          ),
          _tile(
            context,
            icon: Icons.file_upload_outlined,
            title: 'Restaurar backup',
            subtitle: 'Cole o conteúdo do backup para restaurar seus dados',
            onTap: () => _restore(context),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Exportar movimentações'),
          _tile(
            context,
            icon: Icons.table_chart_outlined,
            title: 'Exportar CSV',
            subtitle: 'Movimentações em planilha (Excel / Google Sheets)',
            onTap: () => _exportCsv(context),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Importar extrato'),
          _tile(
            context,
            icon: Icons.upload_file_outlined,
            title: 'Importar extrato (CSV / OFX)',
            subtitle: 'Traga lançamentos do seu banco',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatementImportScreen())),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FinancialCard(
        onTap: onTap,
        child: Row(
          children: [
            CircleIcon(icon: icon, color: AppColors.emerald, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context) async {
    final c = context.read<AppController>();
    final json = c.exportBackupJson();
    await _showCopySheet(context,
        title: 'Backup gerado', content: json, filename: 'ifinance-backup.json');
  }

  Future<void> _exportCsv(BuildContext context) async {
    final c = context.read<AppController>();
    final csv = c.exportTransactionsCsv();
    await _showCopySheet(context,
        title: 'CSV gerado',
        content: csv,
        filename: 'ifinance-movimentacoes.csv');
  }

  Future<void> _showCopySheet(
    BuildContext context, {
    required String title,
    required String content,
    required String filename,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerTheme.color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Arquivo sugerido: $filename',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.blackSoft
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      controller: sc,
                      child: SelectableText(
                        content,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11, height: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        showToast(context,
                            'Copiado! Cole onde quiser salvar o arquivo.');
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar tudo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restore(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Cole abaixo o conteúdo do backup (JSON). Isso SUBSTITUIRÁ seus dados atuais.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{ "app": "IFinance", ... }',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final c = context.read<AppController>();
    try {
      final json = jsonDecode(controller.text) as Map<String, dynamic>;
      final count = await c.restoreBackup(json);
      if (context.mounted) {
        showToast(context, 'Backup restaurado ($count registros).');
      }
    } catch (_) {
      if (context.mounted) {
        showToast(context, 'Backup inválido. Verifique o conteúdo colado.',
            error: true);
      }
    }
  }
}
