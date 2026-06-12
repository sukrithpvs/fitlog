// lib/shared/widgets/custom_charts.dart
// Custom chart widgets using Canvas — no external charting library needed.

import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ─── Volume Line Chart ───
// Shows total volume per workout over time as a line chart with gradient fill.

class VolumeLineChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final double height;

  const VolumeLineChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data to display', style: theme.textTheme.bodySmall),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _VolumeLinePainter(
          data: data,
          lineColor: AppColors.accent,
          gridColor: theme.colorScheme.outline.withValues(alpha: 0.15),
          labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          isDark: theme.brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _VolumeLinePainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final bool isDark;

  _VolumeLinePainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPadding = 50.0;
    const bottomPadding = 30.0;
    const topPadding = 10.0;
    const rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final maxValue = data.map((d) => d.value).reduce(max);
    final minValue = data.map((d) => d.value).reduce(min);
    final valueRange = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(fontSize: 10, color: labelColor);

    for (int i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * i / 4);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y-axis labels
      final value = maxValue - (valueRange * i / 4);
      final label = _formatVolume(value);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (chartWidth * i / (data.length - 1).clamp(1, double.infinity));
      final y = topPadding + chartHeight - (chartHeight * (data[i].value - minValue) / valueRange);
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, size.height - bottomPadding);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height - bottomPadding);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.3),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw dots
    final dotPaint = Paint()..color = lineColor;
    final dotBorderPaint = Paint()
      ..color = isDark ? AppColors.darkBg : Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 4, dotBorderPaint);
    }

    // X-axis labels (show first, middle, last)
    final indices = {0, data.length ~/ 2, data.length - 1}.toList();
    for (final i in indices) {
      if (i >= 0 && i < data.length) {
        final tp = TextPainter(
          text: TextSpan(text: data[i].label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(points[i].dx - tp.width / 2, size.height - bottomPadding + 8),
        );
      }
    }
  }

  String _formatVolume(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Weekly Bar Chart ───
// Shows workouts per week as a bar chart.

class WeeklyBarChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final double height;
  final Color? color;

  const WeeklyBarChart({
    super.key,
    required this.data,
    this.height = 180,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data to display', style: theme.textTheme.bodySmall),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WeeklyBarPainter(
          data: data,
          barColor: color ?? AppColors.success,
          gridColor: theme.colorScheme.outline.withValues(alpha: 0.15),
          labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _WeeklyBarPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;

  _WeeklyBarPainter({
    required this.data,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPadding = 30.0;
    const bottomPadding = 30.0;
    const topPadding = 10.0;
    const rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final maxValue = data.map((d) => d.value).reduce(max).clamp(1.0, double.infinity);

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(fontSize: 10, color: labelColor);

    final gridSteps = maxValue <= 3 ? maxValue.toInt() : 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topPadding + (chartHeight * i / gridSteps);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final value = (maxValue - (maxValue * i / gridSteps)).round();
      final tp = TextPainter(
        text: TextSpan(text: '$value', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // Bars
    final barWidth = (chartWidth / data.length) * 0.6;
    final barGap = (chartWidth / data.length) * 0.4;

    for (int i = 0; i < data.length; i++) {
      final barHeight = chartHeight * (data[i].value / maxValue);
      final x = leftPadding + (chartWidth * i / data.length) + barGap / 2;
      final y = topPadding + chartHeight - barHeight;

      // Bar with rounded top
      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            barColor.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(barRect, barPaint);

      // Value on top of bar
      if (data[i].value > 0) {
        final valueTp = TextPainter(
          text: TextSpan(
            text: data[i].value.toInt().toString(),
            style: labelStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        valueTp.paint(canvas, Offset(x + barWidth / 2 - valueTp.width / 2, y - valueTp.height - 4));
      }

      // X-axis label
      final tp = TextPainter(
        text: TextSpan(text: data[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, size.height - bottomPadding + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Data Model ───

class ChartDataPoint {
  final String label;
  final double value;

  const ChartDataPoint({required this.label, required this.value});
}
