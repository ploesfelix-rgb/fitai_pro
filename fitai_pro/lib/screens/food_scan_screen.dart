// lib/screens/food_scan_screen.dart
//
// Modulo nutricional: captura de plato por camara, analisis via FoodApiClient,
// bottom sheet con desglose + Smart Coach, y failsafe de entrada manual.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/food_api_client.dart';
import '../data/food_repository.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});
  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  CameraController? _cam;
  bool _initializing = false;
  bool _busy = false;

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (_cam != null || _initializing) return;
    setState(() => _initializing = true);
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctl = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await ctl.initialize();
      if (!mounted) return;
      setState(() {
        _cam = ctl;
        _initializing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _captureAndAnalyze() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await cam.takePicture();
      final repo = FoodRepository(context.read<AppState>());
      final result = await repo.logMealFromPhoto(shot.path); // borra la imagen dentro
      if (!mounted) return;
      if (result.ok) {
        _showResult(result);
      } else {
        _showManualFailsafe(result.failReason ?? 'No se pudo analizar el plato.');
      }
    } catch (_) {
      if (mounted) _showManualFailsafe('No se pudo procesar la captura.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(FoodLogResult r) {
    final a = r.analysis!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.foodName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          Text('${a.estimatedWeightG.toStringAsFixed(0)} g estimados',
              style: const TextStyle(color: cDim, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _macro('${a.calories.toStringAsFixed(0)}', 'KCAL', cGreen),
            _macro('${a.proteinsG.toStringAsFixed(0)}g', 'PROT', cGreen),
            _macro('${a.carbsG.toStringAsFixed(0)}g', 'CARB', cAmber),
            _macro('${a.fatsG.toStringAsFixed(0)}g', 'GRASA', cCoral),
          ]),
          const SizedBox(height: 18),
          if (r.coachAdvice != null) ...[
            const Text('[ ANALISIS DE ENTORNO NUTRICIONAL FITAI ]',
                style: TextStyle(fontFamily: mono, fontSize: 10, color: cGreen, letterSpacing: .5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cLine),
              ),
              child: Text(r.coachAdvice!,
                  style: const TextStyle(color: cDim, height: 1.55, fontSize: 13)),
            ),
            const SizedBox(height: 18),
          ],
          bracketButton('[ ANADIDO A MI DIA DE HOY ]', () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  void _showManualFailsafe(String reason) {
    final kcalC = TextEditingController();
    final pC = TextEditingController();
    final cC = TextEditingController();
    final fC = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ENTRADA MANUAL',
              style: TextStyle(fontFamily: mono, fontSize: 13, fontWeight: FontWeight.w900, color: cAmber)),
          const SizedBox(height: 6),
          Text(reason, style: const TextStyle(color: cDim, fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _input(kcalC, 'KCAL')),
            const SizedBox(width: 8),
            Expanded(child: _input(pC, 'PROT g')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _input(cC, 'CARB g')),
            const SizedBox(width: 8),
            Expanded(child: _input(fC, 'GRASA g')),
          ]),
          const SizedBox(height: 16),
          bracketButton('[ GUARDAR EN MI DIA ]', () async {
            final st = context.read<AppState>();
            await st.addFood(
              double.tryParse(kcalC.text) ?? 0,
              double.tryParse(pC.text) ?? 0,
              double.tryParse(cC.text) ?? 0,
              double.tryParse(fC.text) ?? 0,
            );
            if (mounted) Navigator.pop(context);
          }),
        ]),
      ),
    );
  }

  Widget _macro(String v, String l, Color c) => Column(children: [
        Text(v, style: TextStyle(fontFamily: mono, fontSize: 18, fontWeight: FontWeight.w900, color: c)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(fontFamily: mono, fontSize: 9, color: cDim)),
      ]);

  Widget _input(TextEditingController c, String hint) => TextField(
        controller: c,
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        sectionTitle('ESCANER NUTRICIONAL'),
        const SizedBox(height: 14),
        if (_cam == null)
          card(
            child: Column(children: [
              const Text('Enfoca tu plato para analizar sus macronutrientes',
                  style: TextStyle(color: cDim, fontSize: 13)),
              const SizedBox(height: 14),
              bracketButton(
                _initializing ? '[ INICIANDO CAMARA... ]' : '[ ACTIVAR CAMARA ]',
                _initializing ? () {} : _initCamera,
              ),
              const SizedBox(height: 10),
              bracketButton('[ INTRODUCIR A MANO ]',
                  () => _showManualFailsafe('Introduce los macros de tu plato.'),
                  color: cAmber),
            ]),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(aspectRatio: 3 / 4, child: CameraPreview(_cam!)),
          ),
          const SizedBox(height: 14),
          bracketButton(_busy ? '[ ANALIZANDO PLATO... ]' : '[ CAPTURAR Y ANALIZAR ]',
              _busy ? () {} : _captureAndAnalyze),
        ],
      ],
    );
  }
}
