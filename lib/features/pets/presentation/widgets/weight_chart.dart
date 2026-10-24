import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/pet_media.dart';
import '../pet_format.dart';
import '../pet_style.dart';

/// Courbe « Poids & Croissance » de la fiche animal (pesées les plus anciennes à gauche).
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.entries});

  /// Pesées triées de la plus ancienne à la plus récente.
  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final months = entries.map((e) => '${e.measuredOn.year}-${e.measuredOn.month}').toSet();
    final sameMonth = months.length < entries.length;
    String label(WeightEntry e) =>
        sameMonth ? '${e.measuredOn.day} ${formatShortMonth(l, e.measuredOn)}' : formatShortMonth(l, e.measuredOn);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeightPainter(entries.map((e) => e.weightKg).toList(), (kg) => formatKg(l, kg)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: entries.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Text(
                    i == entries.length - 1 ? '${label(entries[i])} ${l.petsWeightCurrent}' : label(entries[i]),
                    style: i == entries.length - 1
                        ? PetText.labelSm.copyWith(color: PetColors.primary, fontWeight: FontWeight.w700)
                        : PetText.labelSm,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.values, this.format);

  final List<double> values;
  final String Function(double kg) format;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final guide = Paint()
      ..color = PetColors.surfaceContainer
      ..strokeWidth = 1;
    for (final ratio in const [0.2, 0.55, 0.9]) {
      final y = h * ratio;
      for (double x = 0; x < w; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3 > w ? w : x + 3, y), guide);
      }
    }
    if (values.isEmpty) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = h * 0.22;
    final bottom = h * 0.75;
    final left = w * 20 / 320;
    final right = w * 300 / 320;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1 ? w / 2 : left + i * (right - left) / (values.length - 1),
          maxV == minV ? (top + bottom) / 2 : bottom - (values[i] - minV) / (maxV - minV) * (bottom - top),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    if (points.length > 1) {
      final fill = Path.from(line)
        ..lineTo(points.last.dx, h)
        ..lineTo(points.first.dx, h)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PetColors.primaryContainer.withValues(alpha: 0.28), PetColors.primaryContainer.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = PetColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      final p = points[i];
      canvas.drawCircle(p, last ? 5.5 : 4.5, Paint()..color = last ? PetColors.primary : Colors.white);
      canvas.drawCircle(
        p,
        last ? 5.5 : 4.5,
        Paint()
          ..color = last ? Colors.white : PetColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final text = TextPainter(
        text: TextSpan(
          text: format(values[i]),
          style: TextStyle(
            fontSize: last ? 11 : 10,
            fontWeight: last ? FontWeight.w700 : FontWeight.w600,
            color: last ? PetColors.primary : PetColors.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(p.dx - text.width / 2, p.dy - 10 - text.height));
    }
  }

  @override
  bool shouldRepaint(_WeightPainter oldDelegate) => oldDelegate.values != values;
}
