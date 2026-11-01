import 'package:flutter/material.dart';

/// KenLab monogram: an antenna mast forms the K, while its right strokes also
/// read as an A-shaped tower with a broadcast signal.
class KenLabMark extends StatelessWidget {
  const KenLabMark({
    required this.size,
    required this.color,
    required this.accent,
    super.key,
  });

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _KenLabMarkPainter(color: color, accent: accent),
        ),
      );
}

class _KenLabMarkPainter extends CustomPainter {
  const _KenLabMarkPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide;
    final stroke = scale * .085;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Tower mast and K spine.
    canvas.drawLine(Offset(scale * .25, scale * .2),
        Offset(scale * .25, scale * .8), paint);
    // K's upper and lower arms form the two legs of a radio tower A.
    final tower = Path()
      ..moveTo(scale * .25, scale * .72)
      ..lineTo(scale * .68, scale * .2)
      ..lineTo(scale * .9, scale * .8)
      ..moveTo(scale * .42, scale * .52)
      ..lineTo(scale * .77, scale * .52)
      ..moveTo(scale * .25, scale * .5)
      ..lineTo(scale * .62, scale * .5);
    canvas.drawPath(tower, paint);

    final details = Paint()
      ..color = accent
      ..strokeWidth = stroke * .52
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(scale * .15, scale * .32),
        Offset(scale * .35, scale * .32), details);
    canvas.drawLine(Offset(scale * .12, scale * .68),
        Offset(scale * .36, scale * .68), details);
    canvas.drawCircle(Offset(scale * .25, scale * .12), scale * .045,
        Paint()..color = accent);

    // Radio waves coming from the antenna tip.
    final wavePaint = Paint()
      ..color = accent
      ..strokeWidth = stroke * .42
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(scale * .25, scale * .12), radius: scale * .14),
        -2.25,
        1.2,
        false,
        wavePaint);
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(scale * .25, scale * .12), radius: scale * .23),
        -2.25,
        1.2,
        false,
        wavePaint);
  }

  @override
  bool shouldRepaint(covariant _KenLabMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}
