// lib/widgets/ui.dart  -- helpers de interfaz compartidos
import 'package:flutter/material.dart';
import '../core/theme.dart';

Widget sectionTitle(String t) => Text(t,
    style: const TextStyle(
        fontFamily: mono, fontSize: 14, fontWeight: FontWeight.w900,
        color: Colors.white, letterSpacing: .5));

Widget card({required Widget child, EdgeInsets? padding}) => Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cSurface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cLine),
      ),
      child: child,
    );

Widget statBlock(String v, String l) => Column(children: [
      Text(v, style: const TextStyle(
          fontFamily: mono, fontSize: 26, fontWeight: FontWeight.w900, color: cGreen)),
      const SizedBox(height: 2),
      Text(l, style: const TextStyle(fontFamily: mono, fontSize: 9, color: cDim)),
    ]);

Widget amberBanner(String head, String body) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cAmber.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cAmber),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head, style: const TextStyle(
            fontFamily: mono, fontSize: 11, fontWeight: FontWeight.w900, color: cAmber)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontSize: 12, color: cDim, height: 1.5)),
      ]),
    );

class BracketButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const BracketButton(this.label, this.onTap, {super.key, this.color = cGreen});
  @override
  State<BracketButton> createState() => _BracketButtonState();
}

class _BracketButtonState extends State<BracketButton> {
  bool p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => p = true),
      onTapUp: (_) => setState(() => p = false),
      onTapCancel: () => setState(() => p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color),
          color: p ? widget.color.withOpacity(.12) : Colors.transparent,
        ),
        child: Text(widget.label, style: TextStyle(
            fontFamily: mono, fontSize: 12, fontWeight: FontWeight.w800,
            letterSpacing: .5, color: widget.color)),
      ),
    );
  }
}

Widget bracketButton(String l, VoidCallback t, {Color color = cGreen}) =>
    BracketButton(l, t, color: color);
