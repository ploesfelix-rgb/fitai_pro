// lib/widgets/flip_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class MetricFlipCard extends StatefulWidget {
  final String metricKey;
  final List<String> meta; // [titulo, ej1, ej2]
  const MetricFlipCard({super.key, required this.metricKey, required this.meta});
  @override
  State<MetricFlipCard> createState() => _MetricFlipCardState();
}

class _MetricFlipCardState extends State<MetricFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _front = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _flip() {
    _front ? _c.forward() : _c.reverse();
    setState(() => _front = !_front);
  }

  void _help() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          '${widget.meta[0]}: indicador de composicion estimado por FitAI a partir '
          'de tu foto. Es una estimacion orientativa, no una medicion clinica. '
          'FitAI prioriza ${widget.meta[1]} y ${widget.meta[2]} para mejorarlo.',
          style: const TextStyle(color: cDim, height: 1.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final v = st.metrics[widget.metricKey] ?? 0;
    final isFocus = st.focusMetric() == widget.metricKey;
    final prioritized = st.priorityFix.contains(widget.metricKey);

    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final angle = _c.value * 3.1416;
          final back = angle > 1.5708;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
            child: back
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.1416),
                    child: _backFace(st, prioritized),
                  )
                : _frontFace(v, isFocus),
          );
        },
      ),
    );
  }

  Widget _frontFace(double v, bool isFocus) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isFocus ? cAmber : cLine, width: isFocus ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isFocus)
                  const Text('PRIORITARIO',
                      style: TextStyle(fontFamily: mono, fontSize: 7, color: cAmber))
                else
                  const SizedBox(),
                GestureDetector(
                  onTap: _help,
                  child: const Text('(?)',
                      style: TextStyle(fontFamily: mono, fontSize: 10, color: cDim)),
                ),
              ],
            ),
            Text(widget.meta[0],
                style: const TextStyle(fontFamily: mono, fontSize: 9, color: cDim)),
            Text(v.toStringAsFixed(2),
                style: const TextStyle(
                    fontFamily: mono, fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const Text('[ TOQUE PARA EXPANDIR ]',
                style: TextStyle(fontFamily: mono, fontSize: 7, color: cDim)),
          ],
        ),
      );

  Widget _backFace(AppState st, bool prioritized) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [cGreen.withOpacity(.08), cSurface2],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CORRIGE ${widget.meta[0]}',
                style: const TextStyle(fontFamily: mono, fontSize: 8, color: cGreen)),
            Text('1. ${widget.meta[1]}',
                style: const TextStyle(fontSize: 10, color: Colors.white)),
            Text('2. ${widget.meta[2]}',
                style: const TextStyle(fontSize: 10, color: Colors.white)),
            GestureDetector(
              onTap: () => st.togglePriority(widget.metricKey),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: cGreen),
                  color: prioritized ? cGreen.withOpacity(.15) : null,
                ),
                child: Text(prioritized ? '[ PRIORIZADO ]' : '[ PRIORIZAR HOY ]',
                    style: const TextStyle(
                        fontFamily: mono, fontSize: 8, fontWeight: FontWeight.w800, color: cGreen)),
              ),
            ),
          ],
        ),
      );
}
