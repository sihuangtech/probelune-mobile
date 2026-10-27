import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';

class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.buckets, required this.width});
  final List<Json> buckets;
  final int width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Latency history by node in milliseconds',
    child: SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(painter: _HistoryPainter(buckets, width)),
    ),
  );
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter(this.buckets, this.width);
  final List<Json> buckets;
  final int width;
  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final times = buckets.map((b) => (b['at'] as num).toDouble());
    final minX = times.reduce(math.min), maxX = times.reduce(math.max);
    final maxY = buckets
        .map((b) => (b['latency_ms'] as num? ?? 0).toDouble())
        .fold<double>(1, math.max);
    final axes = Paint()
      ..color = const Color(0xffdce5df)
      ..strokeWidth = 1;
    for (var n = 0; n < 4; n++) {
      final y = 12 + (size.height - 38) * n / 3;
      canvas.drawLine(Offset(36, y), Offset(size.width, y), axes);
    }
    void label(String text, Offset offset) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 10, color: Color(0xff63747a)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, offset);
    }

    label('${maxY.toStringAsFixed(0)} ms', const Offset(0, 0));
    label('0', Offset(20, size.height - 34));
    final colors = [
      const Color(0xff087f73),
      const Color(0xff628fbc),
      const Color(0xffba8645),
      const Color(0xff9873b0),
    ];
    final ids = buckets.map((b) => b['node_id'] as String).toSet().toList();
    for (var i = 0; i < ids.length; i++) {
      final samples = buckets.where((b) => b['node_id'] == ids[i]).toList()
        ..sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
      Offset? last;
      int? lastAt;
      final pen = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = 2;
      for (final b in samples) {
        final at = b['at'] as int;
        final latency = b['latency_ms'] as num?;
        if (latency == null || (b['success'] as int) == 0) {
          last = null;
          continue;
        }
        final point = Offset(
          36 + (at - minX) / math.max(1, maxX - minX) * (size.width - 42),
          12 + (1 - latency / maxY) * (size.height - 38),
        );
        // 不连跨越缺测时段的线，避免把离线窗口画成连续正常。
        if (last != null && lastAt != null && at - lastAt <= width * 2) {
          canvas.drawLine(last, point, pen);
        }
        canvas.drawCircle(point, 2, pen);
        last = point;
        lastAt = at;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter old) =>
      old.buckets != buckets || old.width != width;
}
