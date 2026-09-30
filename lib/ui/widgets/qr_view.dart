import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renderiza um QR Code a partir de um texto (ex.: URI otpauth://) sem
/// dependências nativas — desenha os módulos com CustomPainter.
class QrView extends StatelessWidget {
  final String data;
  final double size;
  final Color color;
  final Color background;

  const QrView({
    super.key,
    required this.data,
    this.size = 200,
    this.color = Colors.black,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _QrPainter(data: data, color: color),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final Color color;

  _QrPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(qr);
    final n = image.moduleCount;
    final cell = size.width / n;
    final paint = Paint()..color = color;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell + 0.5, cell + 0.5),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) =>
      old.data != data || old.color != color;
}
