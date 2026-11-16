import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import 'common.dart';

class LineageGraph extends StatelessWidget {
  const LineageGraph({super.key, required this.lineage});
  final Map<String, dynamic> lineage;

  @override
  Widget build(BuildContext context) {
    final nodes = asList(lineage['nodes']).map(asMap).toList();
    final edges = asList(lineage['edges']).map(asMap).toList();
    final labels = {for (final node in nodes) asString(node['id']): asString(node['label'])};

    if (nodes.isEmpty) {
      return const SalusCard(
        child: Text('No lineage has been recorded for this incident.', style: TextStyle(color: SalusColors.muted)),
      );
    }

    final sourceCount = nodes.where((node) => _isSource(node)).length;
    final middleCount = nodes.where((node) => !_isSource(node) && !_isSuspect(node)).length;
    final suspectCount = nodes.where(_isSuspect).length;
    final rows = math.max(math.max(sourceCount, middleCount), math.max(suspectCount, 1));
    final height = math.max(280.0, 120.0 + rows * 92.0);

    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Lineage graph',
            subtitle: 'Every edge references a stored event or a stored match. No italic guesses.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, height),
                  painter: _LineagePainter(
                    nodes: nodes,
                    edges: edges,
                    width: constraints.maxWidth,
                    height: height,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _LegendDot(color: SalusColors.mint, label: 'Dataset'),
              _LegendDot(color: SalusColors.red, label: 'Suspect'),
              _LegendDot(color: SalusColors.blue, label: 'User'),
              _LegendDot(color: SalusColors.amber, label: 'Destination'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            'EDGE REFERENCES',
            style: TextStyle(
              color: SalusColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ...edges.map((edge) {
            final ref = asMap(edge['ref']);
            final from = labels[asString(edge['from'])] ?? asString(edge['from']);
            final to = labels[asString(edge['to'])] ?? asString(edge['to']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    asString(ref['type']) == 'MATCH' ? Icons.link : Icons.bolt,
                    size: 14,
                    color: asString(ref['type']) == 'MATCH' ? SalusColors.amber : SalusColors.mint,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 190,
                    child: Text(
                      prettyAction(asString(edge['relation'])),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$from  to  $to',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RefChip(
                    type: asString(ref['type'], 'EVENT'),
                    id: asString(ref['id']),
                    simulated: asBool(edge['simulated']),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static bool _isSuspect(Map<String, dynamic> node) {
    return asString(node['type']) == 'ASSET' && asBool(asMap(node['meta'])['suspect']);
  }

  static bool _isSource(Map<String, dynamic> node) {
    return asString(node['type']) == 'ASSET' && !asBool(asMap(node['meta'])['suspect']);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: SalusColors.muted, fontSize: 11.5)),
      ],
    );
  }
}

class _LineagePainter extends CustomPainter {
  _LineagePainter({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
  });

  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final double width;
  final double height;

  static const double nodeWidth = 170;
  static const double nodeHeight = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _layout();
    final rects = {
      for (final entry in positions.entries)
        entry.key: Rect.fromCenter(
          center: entry.value,
          width: nodeWidth,
          height: nodeHeight,
        ),
    };

    final gridPaint = Paint()
      ..color = SalusColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final entry in positions.entries) {
      canvas.drawLine(
        Offset(entry.value.dx, 10),
        Offset(entry.value.dx, height - 10),
        gridPaint..color = SalusColors.border.withValues(alpha: 0.18),
      );
    }

    for (final edge in edges) {
      final from = rects[asString(edge['from'])];
      final to = rects[asString(edge['to'])];
      if (from == null || to == null) continue;
      final isMatch = asString(asMap(edge['ref'])['type']) == 'MATCH';
      final simulated = asBool(edge['simulated']);
      final paint = Paint()
        ..color = (isMatch ? SalusColors.amber : SalusColors.mint).withValues(alpha: 0.75)
        ..strokeWidth = isMatch ? 2.2 : 1.6
        ..style = PaintingStyle.stroke;
      _drawLine(canvas, from.center, to.center, paint, dashed: simulated);
      _drawArrow(canvas, from.center, to.center, paint.color);
    }

    for (final node in nodes) {
      final rect = rects[asString(node['id'])];
      if (rect == null) continue;
      _drawNode(canvas, rect, node);
    }
  }

  Map<String, Offset> _layout() {
    final source = <Map<String, dynamic>>[];
    final middle = <Map<String, dynamic>>[];
    final suspect = <Map<String, dynamic>>[];
    for (final node in nodes) {
      if (LineageGraph._isSource(node)) {
        source.add(node);
      } else if (LineageGraph._isSuspect(node)) {
        suspect.add(node);
      } else {
        middle.add(node);
      }
    }

    final positions = <String, Offset>{};
    _place(positions, source, 0.14);
    _place(positions, middle, 0.5);
    _place(positions, suspect, 0.86);
    return positions;
  }

  void _place(Map<String, Offset> positions, List<Map<String, dynamic>> group, double xFraction) {
    if (group.isEmpty) return;
    final top = 54.0;
    final bottom = height - 54.0;
    final step = group.length == 1 ? 0.0 : (bottom - top) / (group.length - 1);
    for (var index = 0; index < group.length; index++) {
      final y = group.length == 1 ? height / 2 : top + step * index;
      positions[asString(group[index]['id'])] = Offset(width * xFraction, y);
    }
  }

  void _drawLine(Canvas canvas, Offset from, Offset to, Paint paint, {required bool dashed}) {
    final delta = to - from;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    final start = from + direction * (nodeWidth / 2);
    final end = to - direction * (nodeWidth / 2.6);
    if (!dashed) {
      canvas.drawLine(start, end, paint);
      return;
    }
    const dash = 7.0;
    const gap = 5.0;
    var travelled = 0.0;
    while (travelled < (end - start).distance) {
      final next = math.min(travelled + dash, (end - start).distance);
      canvas.drawLine(start + direction * travelled, start + direction * next, paint);
      travelled = next + gap;
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final delta = to - from;
    if (delta.distance == 0) return;
    final direction = delta / delta.distance;
    final tip = to - direction * (nodeWidth / 2.6);
    final normal = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - direction.dx * 10 + normal.dx * 5, tip.dy - direction.dy * 10 + normal.dy * 5)
      ..lineTo(tip.dx - direction.dx * 10 - normal.dx * 5, tip.dy - direction.dy * 10 - normal.dy * 5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawNode(Canvas canvas, Rect rect, Map<String, dynamic> node) {
    final type = asString(node['type']);
    final suspect = LineageGraph._isSuspect(node);
    final source = LineageGraph._isSource(node);
    final color = suspect
        ? SalusColors.red
        : source
            ? SalusColors.mint
            : type == 'DESTINATION'
                ? SalusColors.amber
                : SalusColors.blue;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 3)), const Radius.circular(12)),
      shadow,
    );

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.18), SalusColors.surfaceAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.65),
    );

    final meta = asMap(node['meta']);
    final title = _text(
      asString(node['label']),
      color: SalusColors.text,
      size: 12.5,
      weight: FontWeight.w700,
      maxWidth: rect.width - 20,
      maxLines: 1,
    );
    final subtitleParts = [
      asString(node['id']),
      if (meta['rows'] != null) '${formatInt(meta['rows'])} rows',
      if (meta['sensitivity'] != null) asString(meta['sensitivity']),
      if (suspect) 'SUSPECT',
    ];
    final subtitle = _text(
      subtitleParts.join('  |  '),
      color: SalusColors.muted,
      size: 9.5,
      maxWidth: rect.width - 20,
      maxLines: 1,
    );

    final badge = _text(
      suspect
          ? 'SUSPECT ASSET'
          : source
              ? 'SOURCE ASSET'
              : type == 'DESTINATION'
                  ? 'DESTINATION'
                  : 'USER',
      color: color,
      size: 8.5,
      weight: FontWeight.w800,
      maxWidth: rect.width - 20,
    );
    badge.paint(canvas, rect.topLeft + const Offset(10, 8));
    title.paint(canvas, rect.topLeft + const Offset(10, 21));
    subtitle.paint(canvas, rect.topLeft + const Offset(10, 42));
  }

  TextPainter _text(
    String text, {
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w400,
    required double maxWidth,
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    return painter;
  }

  @override
  bool shouldRepaint(covariant _LineagePainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.width != width ||
        oldDelegate.height != height;
  }
}
