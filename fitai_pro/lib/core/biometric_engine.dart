// lib/core/biometric_engine.dart
//
// Motor biometrico LOCAL del escaner corporal (Modulo 3).
// Usa google_mlkit_pose_detection para detectar el esqueleto en una imagen.
//
// HONESTIDAD TECNICA (leer):
//   - La deteccion de pose es REAL: ML Kit devuelve 33 landmarks (hombros,
//     cadera, rodillas, etc.) con coordenadas en pixeles.
//   - De esos puntos SI se pueden medir proporciones oseas reales:
//     anchura de hombros, anchura de cadera, ratio hombro/cadera (forma de V),
//     longitud de tronco y simetria izquierda/derecha.
//   - Lo que NO es medible desde pose: porcentaje de grasa, "relieve de
//     deltoides", "potencial genetico". Esas salidas se derivan por HEURISTICA
//     a partir de las proporciones, y se marcan como estimaciones, no medicion.

import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseResult {
  final bool valid;
  final String? reason;       // motivo de rechazo si valid == false
  final Map<String, double> metrics; // metricas derivadas (0..~1.4)
  final double bodyFatEstimate;
  PoseResult({
    required this.valid,
    this.reason,
    this.metrics = const {},
    this.bodyFatEstimate = 0,
  });
}

class BiometricEngine {
  BiometricEngine._();
  static final BiometricEngine instance = BiometricEngine._();

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );

  Future<void> dispose() async => _detector.close();

  /// Procesa una imagen del disco y devuelve metricas o motivo de rechazo.
  Future<PoseResult> analyze(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final poses = await _detector.processImage(input);

    if (poses.isEmpty) {
      return PoseResult(
          valid: false,
          reason: 'No se detecto una silueta corporal. Asegurate de que tu '
              'cuerpo completo entra en el encuadre, con buena luz.');
    }
    final pose = poses.first;
    final lm = pose.landmarks;

    // landmarks clave necesarios para validar el esqueleto
    final lShoulder = lm[PoseLandmarkType.leftShoulder];
    final rShoulder = lm[PoseLandmarkType.rightShoulder];
    final lHip = lm[PoseLandmarkType.leftHip];
    final rHip = lm[PoseLandmarkType.rightHip];
    final lKnee = lm[PoseLandmarkType.leftKnee];
    final rKnee = lm[PoseLandmarkType.rightKnee];

    // validacion: deben existir y tener confianza suficiente
    final required = [lShoulder, rShoulder, lHip, rHip, lKnee, rKnee];
    if (required.any((p) => p == null)) {
      return PoseResult(
          valid: false,
          reason: 'No se detectaron todos los puntos clave (hombros, cadera, '
              'rodillas). Reintenta de pie y de frente.');
    }
    final lowConfidence =
        required.where((p) => (p!.likelihood) < 0.5).isNotEmpty;
    if (lowConfidence) {
      return PoseResult(
          valid: false,
          reason: 'La imagen es borrosa u oscura para un analisis fiable. '
              'Captura otra con mas luz.');
    }

    // ---- mediciones REALES desde los landmarks (en pixeles) ----
    double dist(PoseLandmark a, PoseLandmark b) =>
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

    final shoulderW = dist(lShoulder!, rShoulder!);
    final hipW = dist(lHip!, rHip!);
    final torsoH = (((lShoulder.y + rShoulder.y) / 2) -
            ((lHip.y + rHip.y) / 2))
        .abs();

    // ratio hombro/cadera: forma de V (estructura escapular real)
    final vRatio = hipW > 0 ? shoulderW / hipW : 1.0;
    // simetria: cuanto se desvian los lados (hombros y caderas nivelados)
    final shoulderTilt = (lShoulder.y - rShoulder.y).abs();
    final hipTilt = (lHip.y - rHip.y).abs();
    final symmetry =
        (1.0 - ((shoulderTilt + hipTilt) / (shoulderW + 1)).clamp(0.0, 1.0));

    // normalizaciones a los rangos que usa la UI (0..~1.4)
    final scapular = (vRatio / 1.6).clamp(0.4, 1.4); // V mas ancha => mayor
    final chest = (shoulderW / (torsoH + 1) * 0.9).clamp(0.2, 1.0);
    final lat = (vRatio * 0.55).clamp(0.2, 1.0);
    final delt = (shoulderW / (hipW + shoulderW) * 1.2).clamp(0.2, 1.0);

    // ---- HEURISTICA (no medicion directa): se deriva, no se "mide" ----
    // proporcion cintura/altura aproximada como proxy muy grueso de adiposidad
    final abAdipose = (hipW / (shoulderW + 1)).clamp(0.1, 1.0);
    final bodyFatEstimate = (18 + (abAdipose - 0.5) * 20).clamp(8.0, 35.0);

    return PoseResult(
      valid: true,
      metrics: {
        'chest': _r(chest),
        'abadipose': _r(abAdipose),
        'scapular': _r(scapular),
        'delt': _r(delt),
        'lat': _r(lat),
        'symmetry': _r(symmetry),
      },
      bodyFatEstimate: _r(bodyFatEstimate.toDouble()),
    );
  }

  double _r(double v) => (v * 100).round() / 100;
}
