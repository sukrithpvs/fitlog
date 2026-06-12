// lib/shared/widgets/custom_charts.dart
// Custom chart widgets using Canvas — premium smooth bezier curves.

import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ─── Smooth Line Chart ───
// Universal premium line chart with bezier smoothing, gradient fill, and animations.

class SmoothLineChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final double height;
  final Color? color;
  final String? valueFormatter; // e.g. 'k', 'min', etc.

  const SmoothLineChart({
    super.key,
    required this.data,
    this.height = 200,
    this.color,
    this.valueFormatter,
  });

  @override
  State<SmoothLineChart> createState() => _SmoothLineChartState();
}

class _SmoothLineChartState extends State<SmoothLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _controller.forward();
  }

  @override
  void didUpdateWidget(SmoothLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = widget.color ?? AppColors.accent;

    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('No data to display', style: theme.textTheme.bodySmall),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _SmoothLinePainter(
              data: widget.data,
              lineColor: lineColor,
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.15),
              labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              isDark: theme.brightness == Brightness.dark,
              progress: _animation.value,
              valueFormatter: widget.valueFormatter,
            ),
          );
        },
      ),
    );
  }
}

class _SmoothLinePainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final bool isDark;
  final double progress;
  final String? valueFormatter;

  _SmoothLinePainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.isDark,
    required this.progress,
    this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPadding = 40.0;
    const bottomPadding = 30.0;
    const topPadding = 15.0;
    const rightPadding = 15.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final maxValue = data.map((d) => d.value).reduce(max);
    final minValue = data.map((d) => d.value).reduce(min);
    
    // Add 10% padding to top so line doesn't hit the ceiling
    final valueRange = maxValue - minValue == 0 ? 1.0 : (maxValue - minValue) * 1.1;

    // Draw grid lines & Y-axis labels
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final labelStyle = TextStyle(fontSize: 10, color: labelColor);

    for (int i = 0; i <= 4; i++) {
      final y = topPadding + (chartHeight * i / 4);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);

      final value = maxValue - (valueRange * i / 4);
      final label = _formatValue(value);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // Calculate points
    final points = <Offset>[];
    final stepX = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (stepX * i);
      final y = topPadding + chartHeight - (chartHeight * (data[i].value - minValue) / valueRange);
      points.add(Offset(x, y));
    }

    // Create Bezier Path
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        // Control points for smooth curve
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }
    }

    // Measure path and draw up to progress
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final drawLength = metric.length * progress;
      final animatedPath = metric.extractPath(0, drawLength);

      // Draw Gradient Fill
      if (progress > 0) {
        final fillPath = Path.from(animatedPath);
        // Find last point to close the shape
        final lastPoint = metric.getTangentForOffset(drawLength)?.position ?? points.last;
        fillPath.lineTo(lastPoint.dx, size.height - bottomPadding);
        fillPath.lineTo(points.first.dx, size.height - bottomPadding);
        fillPath.close();

        final fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.3 * progress),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));

        canvas.drawPath(fillPath, fillPaint);
      }

      // Draw Line
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Add glow effect
      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.3 * progress)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawPath(animatedPath, glowPaint);
      canvas.drawPath(animatedPath, linePaint);
    }

    // Draw dots and X-axis labels (only for points drawn so far)
    final dotPaint = Paint()..color = lineColor;
    final dotBorderPaint = Paint()
      ..color = isDark ? AppColors.darkBg : Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final targetX = leftPadding + (chartWidth * progress);

    for (int i = 0; i < points.length; i++) {
      if (points[i].dx <= targetX + 1) { // +1 for floating point safety
        canvas.drawCircle(points[i], 4, dotPaint);
        canvas.drawCircle(points[i], 4, dotBorderPaint);

        // Draw X-axis label (Show first, last, and a middle one if plenty)
        final showLabel = (i == 0) || (i == points.length - 1) || (points.length > 5 && i == points.length ~/ 2);
        if (showLabel || points.length <= 5) {
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
  }

  String _formatValue(double value) {
    if (valueFormatter == 'min') {
      return '${value.toStringAsFixed(0)}m';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _SmoothLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}

// ─── Data Model ───

class ChartDataPoint {
  final String label;
  final double value;

  const ChartDataPoint({required this.label, required this.value});
}
