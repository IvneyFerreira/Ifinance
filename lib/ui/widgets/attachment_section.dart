import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/components.dart';
import '../../state/app_controller.dart';

/// Bloco de anexos (comprovantes) de uma movimentação (cap. 42).
/// Permite adicionar, visualizar e remover arquivos — guardados localmente.
class AttachmentSection extends StatelessWidget {
  final String transactionId;
  const AttachmentSection({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final list = c.attachmentsFor(transactionId);
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Comprovantes', style: t.bodySmall),
            const SizedBox(width: 6),
            if (list.isNotEmpty)
              Text('(${list.length})',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pick(context, c),
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Anexar'),
            ),
          ],
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Nenhum comprovante anexado.',
                style: t.bodySmall?.copyWith(color: AppColors.gray400)),
          )
        else
          ...list.map((a) => _tile(context, c, a)),
      ],
    );
  }

  Widget _tile(BuildContext context, AppController c, Attachment a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FinancialCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleIcon(
              icon: a.isImage
                  ? Icons.image_outlined
                  : (a.isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined),
              color: AppColors.emerald,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(a.sizeLabel,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ver',
              icon: const Icon(Icons.visibility_outlined, size: 20),
              onPressed: () => _preview(context, a),
            ),
            IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.negative),
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title: 'Remover comprovante',
                    message: 'Remover "${a.name}"?',
                    confirmLabel: 'Remover',
                    destructive: true);
                if (ok) await c.deleteAttachment(a);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, AppController c) async {
    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (context.mounted) {
        showToast(context, 'Não foi possível ler o arquivo.', error: true);
      }
      return;
    }
    if (bytes.length > 8 * 1024 * 1024) {
      if (context.mounted) {
        showToast(context, 'Arquivo muito grande (máx. 8 MB).', error: true);
      }
      return;
    }
    await c.addAttachment(
      transactionId: transactionId,
      name: f.name,
      mimeType: _mimeFor(f),
      bytes: bytes,
    );
    if (context.mounted) showToast(context, 'Comprovante anexado.');
  }

  String _mimeFor(PlatformFile f) {
    final ext = (f.extension ?? '').toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void _preview(BuildContext context, Attachment a) {
    if (!a.isImage) {
      showToast(context, 'Arquivo: ${a.name} (${a.sizeLabel})');
      return;
    }
    final bytes = base64Decode(a.dataBase64);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(a.name,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(Uint8List.fromList(bytes)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}
