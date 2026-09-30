import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/report_pdf.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';
import 'statement_import_screen.dart';

/// Importar / Exportar (cap. 42/43): backup completo (JSON), exportação em CSV
/// e restauração. Tudo local, sem enviar dados para fora.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
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
          const SizedBox(height: 14),
          FinancialCard(
            color: AppColors.warning.withValues(alpha: 0.10),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Onde ficam seus dados?',
                          style: t.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        'Tudo fica guardado somente neste aparelho (nada vai para '
                        'a nuvem). Por isso, ao DESINSTALAR o app ou trocar de '
                        'celular os dados não vêm junto. Antes de fazer isso, '
                        'gere um backup (JSON) aqui embaixo e guarde-o — depois '
                        'basta usar "Restaurar de um backup" na tela de login.',
                        style: t.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (c.restoredFromSnapshot) ...[
            const SizedBox(height: 14),
            FinancialCard(
              color: AppColors.positive.withValues(alpha: 0.10),
              border:
                  Border.all(color: AppColors.positive.withValues(alpha: 0.35)),
              child: Row(
                children: [
                  const Icon(Icons.restore, color: AppColors.positive, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recuperamos automaticamente seus dados do último backup '
                      'local. Confira se está tudo certo.',
                      style: t.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Backups automáticos (no aparelho)'),
          _autoBackupCard(context, c),
          const SizedBox(height: 16),
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
          const SectionHeader(title: 'Relatórios e planilhas'),
          _tile(
            context,
            icon: Icons.picture_as_pdf_outlined,
            title: 'Relatório em PDF',
            subtitle: 'Resumo do período, fluxo mensal e categorias',
            onTap: () => _exportPdf(context),
          ),
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

  Widget _autoBackupCard(BuildContext context, AppController c) {
    final t = Theme.of(context).textTheme;
    final snapshots = c.listSnapshots();
    final usedKb = (c.snapshotStorageUsed / 1024).toStringAsFixed(1);
    return FinancialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleIcon(
                  icon: Icons.history, color: AppColors.emerald, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proteção contra perda de dados',
                        style: t.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Guardamos as últimas ${BackupService.maxSnapshots} cópias '
                      'no aparelho e recuperamos tudo se algo for apagado '
                      'numa atualização.',
                      style: t.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (snapshots.isEmpty)
            Text('Nenhum backup automático ainda — ele será criado ao usar o app.',
                style: t.bodySmall)
          else
            ...snapshots.map((s) => _snapshotRow(context, c, s)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await c.snapshotNow();
                    if (context.mounted) {
                      showToast(context, 'Backup local criado.');
                    }
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Salvar agora'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Limpar backups locais',
                onPressed: snapshots.isEmpty
                    ? null
                    : () => _confirmClearSnapshots(context, c),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (snapshots.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Espaço usado: $usedKb KB', style: t.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _snapshotRow(
      BuildContext context, AppController c, BackupSnapshotInfo s) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.gray400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateHelpers.dayMonth.format(s.createdAt)} '
                  '${s.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${s.createdAt.minute.toString().padLeft(2, '0')} • '
                  '${s.label}',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text('${s.recordCount} registros',
                    style: t.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _confirmRestoreSnapshot(context, c, s),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestoreSnapshot(
      BuildContext context, AppController c, BackupSnapshotInfo s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup automático'),
        content: Text(
            'Isso SUBSTITUI seus dados atuais pelos ${s.recordCount} registros '
            'salvos em ${DateHelpers.dayMonth.format(s.createdAt)} às '
            '${s.createdAt.hour.toString().padLeft(2, '0')}:'
            '${s.createdAt.minute.toString().padLeft(2, '0')}. '
            'Um backup do estado atual será guardado antes.'),
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
    if (ok != true || !context.mounted) return;
    final count = await c.restoreSnapshot(s.id);
    if (context.mounted) {
      showToast(context, 'Dados restaurados ($count registros).');
    }
  }

  Future<void> _confirmClearSnapshots(
      BuildContext context, AppController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar backups locais'),
        content: const Text(
            'Isso apaga todos os backups automáticos guardados no aparelho. '
            'Recomendamos exportar um backup (JSON) antes. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Limpar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await c.clearSnapshots();
    if (context.mounted) showToast(context, 'Backups locais removidos.');
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

  Future<void> _exportPdf(BuildContext context) async {
    final c = context.read<AppController>();
    final bytes = await ReportPdf.build(
      engine: c.engine,
      transactions: c.transactions,
      categories: c.categories,
      userName: c.user?.name ?? '',
      months: 6,
    );
    await Printing.layoutPdf(
      name: 'ifinance-relatorio.pdf',
      onLayout: (_) => bytes,
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
