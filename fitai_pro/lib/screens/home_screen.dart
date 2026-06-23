// lib/screens/home_screen.dart
//
// Modulo 4: anillo de macros dinamico + calendario historico (lee de la BD).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'food_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const dows = ['DOM', 'LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'];
  Map<String, List<double>> _cache = {}; // dateKey -> record

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStrip());
  }

  Future<void> _loadStrip() async {
    final st = context.read<AppState>();
    final today = DateTime.now();
    final out = <String, List<double>>{};
    for (int i = 0; i < 7; i++) {
      final k = st.dateKey(today.subtract(Duration(days: i)));
      final rec = await st.dayRecord(k);
      if (rec != null) out[k] = rec;
    }
    if (mounted) setState(() => _cache = out);
  }

  String _border(List<double>? rec) {
    if (rec == null || rec[6] == 0) return 'gray';
    final dev = (rec[0] - rec[4]).abs();
    final pdef = rec[5] - rec[1];
    if (pdef > 40 || dev > 400) return 'amber';
    if (dev <= 100 || rec[1] >= rec[5]) return 'green';
    return 'gray';
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final viewing = st.viewDate != null && st.viewDate != st.dateKey();
    final t = st.todayTarget();

    double ck, cp, cc, cf;
    int tk, tp, tc, tf;
    if (viewing) {
      final rec = _cache[st.viewDate!] ?? [0, 0, 0, 0, 0, 0, 0];
      ck = rec[0]; cp = rec[1]; cc = rec[2]; cf = rec[3];
      tk = rec[4].round(); tp = rec[5].round();
      tc = t['c']!; tf = t['f']!;
    } else {
      ck = st.cK; cp = st.cP; cc = st.cC; cf = st.cF;
      tk = t['kcal']!; tp = t['p']!; tc = t['c']!; tf = t['f']!;
    }
    final left = (tk - ck).clamp(0, 99999).toInt();
    final pct = tk > 0 ? (ck / tk).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const Text('FitAI',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 14),
        _strip(st),
        const SizedBox(height: 16),
        card(
          child: Column(children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _RingPainter(pct),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$left',
                        style: const TextStyle(
                            fontFamily: mono, fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('de $tk kcal objetivo',
                        style: const TextStyle(color: cDim, fontSize: 12)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _bar('PROTEINAS', cp.round(), tp, cGreen),
            _bar('CARBOHIDRATOS', cc.round(), tc, cAmber),
            _bar('GRASAS', cf.round(), tf, cCoral),
            const SizedBox(height: 12),
            Text(
                viewing
                    ? 'VIENDO REGISTRO PASADO - solo datos numericos, sin imagenes'
                    : (st.trainedToday()
                        ? 'DIA DE ENTRENO: presupuesto al alza para sintesis proteica.'
                        : 'DIA DE DESCANSO: presupuesto ajustado para el deficit.'),
                style: TextStyle(
                    fontFamily: mono, fontSize: 10, color: viewing ? cAmber : cDim)),
          ]),
        ),
        const SizedBox(height: 14),
        bracketButton('[ ESCANEAR COMIDA CON LA CAMARA ]', () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FoodScanScreen()),
          );
          await _loadStrip();
        }),
      ],
    );
  }

  Widget _strip(AppState st) {
    final today = DateTime.now();
    final viewKey = st.viewDate ?? st.dateKey();
    return SizedBox(
      height: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('[ HAGA CLIC AQUI PARA VIAJAR A DIAS PASADOS ]',
              style: TextStyle(fontFamily: mono, fontSize: 9, color: cDim)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final dt = today.subtract(Duration(days: i));
                final k = st.dateKey(dt);
                final b = _border(_cache[k]);
                final sel = k == viewKey;
                final bc = b == 'green' ? cGreen : b == 'amber' ? cAmber : cLine;
                return GestureDetector(
                  onTap: () {
                    st.viewDate = (k == st.dateKey()) ? null : k;
                    st.notifyListeners();
                  },
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: sel ? cGreen.withOpacity(.1) : cSurface2,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: sel ? cGreen : bc),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i == 0 ? 'HOY' : dows[dt.weekday % 7],
                            style: const TextStyle(fontFamily: mono, fontSize: 8, color: cDim)),
                        const SizedBox(height: 2),
                        Text('${dt.day}',
                            style: TextStyle(
                                fontFamily: mono, fontSize: 15, fontWeight: FontWeight.w900,
                                color: sel ? cGreen : Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, int now, int goal, Color c) {
    final v = goal > 0 ? (now / goal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontFamily: mono, fontSize: 10, color: cDim)),
          Text('$now / $goal g',
              style: const TextStyle(fontFamily: mono, fontSize: 11, color: Colors.white)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
              value: v, minHeight: 5, backgroundColor: cLine,
              valueColor: AlwaysStoppedAnimation(c)),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  _RingPainter(this.pct);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width < size.height ? size.width : size.height) / 2 - 14;
    canvas.drawCircle(c, r,
        Paint()..color = cLine..style = PaintingStyle.stroke..strokeWidth = 16);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708, 6.2832 * pct, false,
      Paint()
        ..color = pct >= 1 ? cCoral : cGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}
