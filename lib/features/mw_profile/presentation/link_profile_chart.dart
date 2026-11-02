import 'package:flutter/material.dart';

import '../models/link_profile.dart';

class LinkProfileChart extends StatelessWidget {
  const LinkProfileChart({required this.profile, super.key});
  final LinkProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.profile.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('El perfil requiere al menos dos muestras de terreno.'),
      );
    }
    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _LinkProfilePainter(
          profile: profile,
          terrainColor: Theme.of(context).colorScheme.secondary,
          losColor: const Color(0xFFC62828),
        ),
        child: const Padding(
          padding: EdgeInsets.only(left: 12, right: 12, bottom: 4),
          child: Align(
            alignment: Alignment.bottomCenter,
            child:
                Text('Distancia del enlace →', style: TextStyle(fontSize: 10)),
          ),
        ),
      ),
    );
  }
}

class _LinkProfilePainter extends CustomPainter {
  const _LinkProfilePainter(
      {required this.profile,
      required this.terrainColor,
      required this.losColor});
  final LinkProfile profile;
  final Color terrainColor;
  final Color losColor;

  @override
  void paint(Canvas canvas, Size size) {
    final points = profile.profile;
    final distances = points.map((point) => point.distanceMeters).toList();
    final altitudes = <double>[
      ...points.map((point) => point.terrainAltitudeMeters),
      ...points
          .map((point) => point.lineOfSightAltitudeMeters)
          .whereType<double>(),
      ...points
          .where((point) =>
              point.fresnelRadiusMeters != null &&
              point.lineOfSightAltitudeMeters != null)
          .expand((point) => [
                point.lineOfSightAltitudeMeters! - point.fresnelRadiusMeters!,
                point.lineOfSightAltitudeMeters! + point.fresnelRadiusMeters!,
              ]),
    ];
    final minX = distances.reduce((a, b) => a < b ? a : b);
    final maxX = distances.reduce((a, b) => a > b ? a : b);
    final minY = altitudes.reduce((a, b) => a < b ? a : b);
    final maxY = altitudes.reduce((a, b) => a > b ? a : b);
    const inset = 16.0;
    final plot = Rect.fromLTWH(
        inset, inset, size.width - inset * 2, size.height - inset * 2 - 18);
    Offset project(double x, double y) => Offset(
          plot.left +
              (x - minX) / (maxX - minX == 0 ? 1 : maxX - minX) * plot.width,
          plot.bottom -
              (y - minY) / (maxY - minY == 0 ? 1 : maxY - minY) * plot.height,
        );

    final terrainPath = Path();
    final losPath = Path();
    var losStarted = false;
    final fresnelPath = Path();
    final fresnelPoints = points
        .where((point) =>
            point.fresnelRadiusMeters != null &&
            point.lineOfSightAltitudeMeters != null)
        .toList(growable: false);
    for (var index = 0; index < fresnelPoints.length; index++) {
      final point = fresnelPoints[index];
      final upper = project(point.distanceMeters,
          point.lineOfSightAltitudeMeters! + point.fresnelRadiusMeters!);
      if (index == 0) {
        fresnelPath.moveTo(upper.dx, upper.dy);
      } else {
        fresnelPath.lineTo(upper.dx, upper.dy);
      }
    }
    for (final point in fresnelPoints.reversed) {
      final lower = project(point.distanceMeters,
          point.lineOfSightAltitudeMeters! - point.fresnelRadiusMeters!);
      fresnelPath.lineTo(lower.dx, lower.dy);
    }
    if (fresnelPoints.isNotEmpty) fresnelPath.close();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final terrain =
          project(point.distanceMeters, point.terrainAltitudeMeters);
      if (index == 0) {
        terrainPath.moveTo(terrain.dx, terrain.dy);
      } else {
        terrainPath.lineTo(terrain.dx, terrain.dy);
      }
      final los = point.lineOfSightAltitudeMeters;
      if (los != null) {
        final location = project(point.distanceMeters, los);
        if (!losStarted) {
          losPath.moveTo(location.dx, location.dy);
          losStarted = true;
        } else {
          losPath.lineTo(location.dx, location.dy);
        }
      }
    }
    canvas.drawRect(
        plot, Paint()..color = Colors.black.withValues(alpha: .025));
    if (fresnelPoints.isNotEmpty) {
      canvas.drawPath(
          fresnelPath,
          Paint()
            ..color = losColor.withValues(alpha: .12)
            ..style = PaintingStyle.fill);
    }
    canvas.drawPath(
        terrainPath,
        Paint()
          ..color = terrainColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    if (losPath.computeMetrics().isNotEmpty) {
      canvas.drawPath(
          losPath,
          Paint()
            ..color = losColor
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
    final labels = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(
          text: 'Terreno',
          style: TextStyle(color: Color(0xFF536B5B), fontSize: 10))
      ..layout();
    labels.paint(canvas, Offset(plot.left + 4, plot.top + 4));
    final losLabel = TextPainter(textDirection: TextDirection.ltr)
      ..text = const TextSpan(
          text: 'Línea de vista',
          style: TextStyle(color: Color(0xFFC62828), fontSize: 10))
      ..layout();
    losLabel.paint(canvas, Offset(plot.left + 58, plot.top + 4));
  }

  @override
  bool shouldRepaint(covariant _LinkProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}
