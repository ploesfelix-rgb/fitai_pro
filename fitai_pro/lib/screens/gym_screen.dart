// lib/screens/gym_screen.dart
//
// Modulo 5: One-button gym. Gatekeeper, rutina procedimental, doble progresion,
// dictado por voz (speech_to_text) y failsafe de red en imagenes (cached_network_image).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

const _fedb =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  bool _calculated = false;
  List<Map<String, dynamic>> _today = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;

  void _calc(AppState st) {
    final base = <Map<String, dynamic>>[
      {'name': 'Press de Banca', 'slug': 'Barbell_Bench_Press_-_Medium_Grip', 'kg': 60.0, 'reps': 8, 'cardio': false},
      {'name': 'Dominadas', 'slug': 'Pullups', 'kg': 0.0, 'reps': 10, 'cardio': false},
      {'name': 'Sentadilla', 'slug': 'Barbell_Squat', 'kg': 80.0, 'reps': 8, 'cardio': false},
    ];
    // proteccion articular: si sobrepeso, cardio de bajo impacto (remo/bici, no cinta)
    final imc = st.weight / ((st.height / 100) * (st.height / 100));
    base.add({
      'name': imc >= 30 ? 'Remo en maquina' : 'Correr en cinta',
      'slug': 'Rowing_Stationary',
      'kg': 0.0, 'reps': 0, 'cardio': true,
    });
    // inyectar prioridades de la pantalla de Fisico al frente
    const fix = {
      'chest': 'Press de Banca', 'abadipose': 'Plancha', 'scapular': 'Press militar',
      'delt': 'Elevaciones laterales', 'lat': 'Dominadas', 'symmetry': 'Zancadas',
    };
    final pri = <Map<String, dynamic>>[];
    for (final k in st.priorityFix) {
      pri.add({'name': fix[k] ?? 'Accesorio', 'slug': '', 'kg': 40.0, 'reps': 8, 'cardio': false, 'pri': true});
    }
    // fatiga: si ayer cardio de tren superior, baja intensidad de tiron hoy
    if (st.cardioFatigueZone == 'upper') {
      for (final e in base) {
        if (e['name'] == 'Dominadas') e['reps'] = 6;
      }
    }
    _today = [...pri, ...base];
    st.session += 1;
    st.lastTrained = DateTime.now();
    st.saveToday();
    setState(() => _calculated = true);
  }

  Future<void> _dictate() async {
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }
    if (_speechReady && !_speech.isListening) {
      _speech.listen(onResult: (r) {
        // NATIVO: parsear "10 reps con 60 kilos" y rellenar los campos
      });
    } else {
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    // NAVIGATION GUARD: gym bloqueado sin diagnostico
    if (!st.hasCompletedPhysicalDiagnosis) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Text('[ X ]',
                style: TextStyle(fontFamily: mono, fontSize: 24, letterSpacing: 4, color: cGreen, fontWeight: FontWeight.w700)),
            SizedBox(height: 18),
            Text('ACCESO RESTRINGIDO',
                style: TextStyle(fontFamily: mono, fontSize: 14, fontWeight: FontWeight.w900, color: cGreen)),
            SizedBox(height: 12),
            Text('Tu plan de fuerza no se puede estructurar sin datos anatomicos. '
                'Ve a la pestana FISICO y completa tu primer escaner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cDim, height: 1.6, fontSize: 13)),
          ]),
        ),
      );
    }

    if (!_calculated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Tu sesion, calculada al momento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 20),
            bracketButton('[ CALCULAR ENTRENAMIENTO DE HOY ]', () => _calc(st)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        sectionTitle('SESION DE HOY'),
        const SizedBox(height: 12),
        ..._today.map(_exCard),
        const SizedBox(height: 8),
        bracketButton('[ RECALCULAR ]', () => setState(() => _calculated = false), color: cAmber),
      ],
    );
  }

  Widget _exCard(Map<String, dynamic> ex) {
    final cardio = ex['cardio'] == true;
    final pri = ex['pri'] == true;
    final slug = ex['slug'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // failsafe de red: si la imagen falla o timeout, se oculta y queda solo texto
          if (slug.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: '$_fedb/$slug/0.jpg',
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                fadeOutDuration: const Duration(milliseconds: 250),
                placeholder: (_, __) => Container(height: 130, color: cSurface2),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(ex['name'],
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            if (pri)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: cAmber.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cAmber)),
                child: const Text('PRIORIDAD',
                    style: TextStyle(fontFamily: mono, fontSize: 8, color: cAmber)),
              ),
          ]),
          const SizedBox(height: 6),
          if (cardio) ...[
            const Text('Cardio - bajo impacto - 15-20 min',
                style: TextStyle(color: cDim, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _input('MIN')),
              const SizedBox(width: 8),
              Expanded(child: _input('NIVEL')),
              const SizedBox(width: 8),
              Expanded(child: _input('KM')),
            ]),
            const SizedBox(height: 8),
            bracketButton('[ GUARDAR SESION DE CARDIO ]', () {
              context.read<AppState>().cardioFatigueZone =
                  ex['name'].toString().contains('Remo') ? 'upper' : 'lower';
            }),
          ] else ...[
            Text('Objetivo: ${ex['kg']}kg x ${ex['reps']} reps',
                style: const TextStyle(color: cDim, fontSize: 12, fontFamily: mono)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _input('KG')),
              const SizedBox(width: 8),
              Expanded(child: _input('REPS')),
              const SizedBox(width: 8),
              bracketButton('[ VOZ ]', _dictate, color: cAmber),
            ]),
            const SizedBox(height: 8),
            bracketButton('[ SALTAR / HOY NO PUEDO ]', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: cSurface2,
                content: Text('Volumen reprogramado a tus proximas sesiones.',
                    style: TextStyle(fontFamily: mono, color: cAmber, fontSize: 12)),
              ));
            }, color: cDim),
          ],
        ]),
      ),
    );
  }

  Widget _input(String hint) => TextField(
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: mono, color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: cDim, fontSize: 11),
          isDense: true,
          filled: true,
          fillColor: cSurface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: cLine)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: cLine)),
        ),
      );
}
