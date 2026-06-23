// lib/screens/onboarding_screen.dart
//
// Modulo 2: onboarding wizard + diagnostico biometrico si brecha >= 12 kg.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  final wC = TextEditingController(text: '82');
  final hC = TextEditingController(text: '178');
  final aC = TextEditingController(text: '28');
  final twC = TextEditingController(text: '76');

  void _next(AppState st) {
    if (_page < 3) {
      _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      st.weight = double.tryParse(wC.text) ?? 82;
      st.height = double.tryParse(hC.text) ?? 178;
      st.age = int.tryParse(aC.text) ?? 28;
      st.targetWeight = double.tryParse(twC.text) ?? 0;
      st.onboarded = true;
      if (st.weightGap().abs() >= 12) {
        showModalBottomSheet(
          context: context,
          backgroundColor: cSurface,
          isScrollControlled: true,
          builder: (_) => _diagnostic(st),
        ).then((_) => st.notifyListeners());
      } else {
        st.notifyListeners();
      }
    }
  }

  Widget _diagnostic(AppState st) {
    final gap = st.weightGap().abs().toStringAsFixed(0);
    final t = st.todayTarget();
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DIAGNOSTICO BIOMETRICO FITAI',
            style: TextStyle(fontFamily: mono, fontSize: 12, color: cAmber, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Text(
            'Objetivo de reduccion de $gap kg. Para alcanzar tu peso objetivo de forma '
            'segura para tus articulaciones y masa muscular, el motor ha pautado un '
            'deficit calorico progresivo. HOY tu cuerpo necesita exactamente ${t['kcal']} '
            'calorias, priorizando un consumo alto de proteinas (${t['p']} gramos) para '
            'regular la saciedad.',
            style: const TextStyle(color: cDim, height: 1.6, fontSize: 13)),
        const SizedBox(height: 12),
        const Text('Estimacion orientativa, no diagnostico medico. Consulta a un '
            'profesional sanitario antes de un cambio de peso importante.',
            style: TextStyle(color: cCoral, fontSize: 11, height: 1.5)),
        const SizedBox(height: 18),
        bracketButton('[ ENTENDIDO, VER MI PLAN ]', () => Navigator.pop(context)),
      ]),
    );
  }

  Widget _field(String label, TextEditingController c, String unit) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontFamily: mono, fontSize: 11, color: cGreen)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: c,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: mono, fontSize: 22, color: Colors.white),
                decoration: InputDecoration(
                  filled: true, fillColor: cSurface2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(unit, style: const TextStyle(color: cDim)),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          LinearProgressIndicator(
              value: (_page + 1) / 4, backgroundColor: cLine,
              valueColor: const AlwaysStoppedAnimation(cGreen)),
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _step('TUS DATOS BASE', [
                  _field('Peso actual', wC, 'kg'),
                  _field('Altura', hC, 'cm'),
                  _field('Edad', aC, 'anos'),
                ]),
                _step('TU OBJETIVO', [
                  Row(children: [
                    Expanded(child: _goalChip(st, 'cut', 'DEFINICION')),
                    const SizedBox(width: 10),
                    Expanded(child: _goalChip(st, 'bulk', 'VOLUMEN')),
                  ]),
                ]),
                _step('PESO OBJETIVO', [_field('A que peso quieres llegar', twC, 'kg')]),
                _step('FECHA OBJETIVO', [
                  bracketButton('[ ELEGIR FECHA EN EL CALENDARIO ]', () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setState(() => st.targetDate = d);
                  }),
                  const SizedBox(height: 12),
                  if (st.targetDate != null)
                    Text('Faltan ${st.targetDate!.difference(DateTime.now()).inDays} dias',
                        style: const TextStyle(fontFamily: mono, color: cGreen, fontSize: 13)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: bracketButton(_page < 3 ? '[ CONTINUAR ]' : '[ CREAR MI PLAN ]', () => _next(st)),
          ),
        ]),
      ),
    );
  }

  Widget _step(String title, List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 26),
          ...children,
        ]),
      );

  Widget _goalChip(AppState st, String val, String label) {
    final on = st.goal == val;
    return GestureDetector(
      onTap: () => setState(() => st.goal = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? cGreen.withOpacity(.1) : cSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? cGreen : cLine),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: mono, fontWeight: FontWeight.w800, color: on ? cGreen : cDim)),
      ),
    );
  }
}
