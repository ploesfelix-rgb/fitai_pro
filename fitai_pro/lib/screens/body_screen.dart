// lib/screens/body_screen.dart
//
// Modulo 3: camara nativa en vivo, validacion por API, extraccion de metricas,
// y borrado atomico e irreversible del archivo de la foto (File.delete()).

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/biometric_engine.dart';
import '../state/app_state.dart';
import '../core/theme.dart';
import '../widgets/flip_card.dart';
import '../widgets/pose_overlay.dart';
import '../widgets/ui.dart';

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});
  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _initializing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'No se pudo iniciar la camara: $e';
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    XFile? shot;
    try {
      shot = await cam.takePicture();

      // ANALISIS LOCAL: deteccion de pose + validacion de keypoints + metricas
      final res = await BiometricEngine.instance.analyze(shot.path);

      if (!res.valid) {
        _showReject(res.reason ??
            'La imagen no tiene la nitidez o iluminacion necesarias. Captura otra.');
      } else {
        if (!mounted) return;
        await context.read<AppState>().completeDiagnosis(
              res.metrics,
              res.bodyFatEstimate,
            );
      }
    } catch (e) {
      _showReject('No se pudo procesar la captura. Reintenta.');
    } finally {
      // VOLATILIDAD ATOMICA: borrar el archivo fisico inmediatamente, pase lo que pase
      if (shot != null) {
        try {
          final f = File(shot.path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showReject(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cSurface,
        title: const Text('ESCANEO RECHAZADO',
            style: TextStyle(fontFamily: mono, color: cCoral, fontSize: 14)),
        content: Text(msg, style: const TextStyle(color: cDim, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('REINTENTAR', style: TextStyle(fontFamily: mono, color: cGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (st.hasCompletedPhysicalDiagnosis) {
      return _results(st);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        sectionTitle('ANALISIS FISICO'),
        const SizedBox(height: 12),
        amberBanner(
          'AVISO DE PRIVACIDAD FITAI',
          'El analisis de pose se ejecuta localmente en tu dispositivo: la imagen '
              'no sale del telefono y se elimina del almacenamiento inmediatamente '
              'tras extraer las proporciones. Nada de tu fisico permanece como archivo.',
        ),
        const SizedBox(height: 16),
        _cameraArea(),
      ],
    );
  }

  Widget _cameraArea() {
    if (_error != null) {
      return card(child: Text(_error!, style: const TextStyle(color: cCoral)));
    }
    if (_cam == null) {
      return card(
        child: Column(children: [
          const Text('Captura tu fisico del Dia 1 (frente y espalda)',
              style: TextStyle(color: cDim, fontSize: 13)),
          const SizedBox(height: 14),
          bracketButton(
            _initializing ? '[ INICIANDO CAMARA... ]' : '[ ACTIVAR CAMARA ]',
            _initializing ? () {} : _initCamera,
          ),
        ]),
      );
    }
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(fit: StackFit.expand, children: [
            CameraPreview(_cam!),
            // guia de silueta verde para encajar el cuerpo (la pose real se
            // valida al capturar, sobre la foto, con ML Kit en local)
            CustomPaint(
              painter: PoseMaskPainter(pose: null, imageSize: const Size(1, 1)),
            ),
            const Align(
              alignment: Alignment(0, 0.88),
              child: Text('ENCAJA TU CUERPO COMPLETO EN LA GUIA',
                  style: TextStyle(
                      fontFamily: mono, fontSize: 10, color: cGreen)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      bracketButton(_busy ? '[ ANALIZANDO POSE... ]' : '[ CAPTURAR Y ANALIZAR ]',
          _busy ? () {} : _captureAndAnalyze),
    ]);
  }

  Widget _results(AppState st) {
    const meta = {
      'chest': ['CHEST RATIO', 'Press de Banca', 'Press inclinado'],
      'abadipose': ['AB. ADIPOSE', 'Plancha', 'Remo en maquina'],
      'scapular': ['SCAPULAR WIDTH', 'Press militar', 'Elevaciones laterales'],
      'delt': ['DELT RELIEF', 'Elevaciones laterales', 'Press militar mancuerna'],
      'lat': ['LAT SPREAD', 'Dominadas', 'Remo con barra'],
      'symmetry': ['SYMMETRY', 'Zancadas', 'Remo con barra'],
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        sectionTitle('COMPOSICION POR ZONAS'),
        const SizedBox(height: 8),
        const Text(
            'Proporciones derivadas de tu pose (hombros, cadera, tronco). La grasa '
            'y el relieve son estimaciones, no medicion clinica.',
            style: TextStyle(fontSize: 10, color: cDim, height: 1.4)),
        const SizedBox(height: 12),
        card(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              statBlock('${st.bodyFat.toStringAsFixed(0)}%', 'GRASA EST.'),
              statBlock('${st.targetWeight.toStringAsFixed(0)}kg', 'PESO OBJETIVO'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: meta.entries
              .map((e) => MetricFlipCard(metricKey: e.key, meta: e.value))
              .toList(),
        ),
      ],
    );
  }
}
