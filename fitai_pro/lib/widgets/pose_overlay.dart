// lib/widgets/pose_overlay.dart
//
// Dibuja la mascara de contorno/esqueleto en verde electrico sobre la camara.
// Recibe la pose ya detectada y la escala al tamano del preview.

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../core/theme.dart';

class PoseMaskPainter extends CustomPainter {
  final Pose? pose;
  final Size imageSize; // tamano de la imagen analizada
  PoseMaskPainter({required this.pose, required this.imageSize});

  // conexiones del esqueleto a dibujar
  static const _bones = <List<PoseLandmarkType>>[
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    if (p == null) {
      // sin pose: guia ovalada estatica
      final guide = Paint()
        ..color = cGreen.withOpacity(.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: size.width * 0.55,
              height: size.height * 0.7),
          const Radius.circular(120),
        ),
        guide,
      );
      return;
    }

    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;
    Offset map(PoseLandmark l) => Offset(l.x * sx, l.y * sy);

    final bone = Paint()
      ..color = cGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = cGreen;

    for (final b in _bones) {
      final a = p.landmarks[b[0]];
      final c = p.landmarks[b[1]];
      if (a != null && c != null) canvas.drawLine(map(a), map(c), bone);
    }
    for (final l in p.landmarks.values) {
      canvas.drawCircle(map(l), 4, joint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseMaskPainter old) =>
      old.pose != pose || old.imageSize != imageSize;
}
