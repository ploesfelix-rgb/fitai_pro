// lib/core/theme.dart
import 'package:flutter/material.dart';

const cBlack = Color(0xFF000000);
const cBg = Color(0xFF0A0A0A);
const cSurface = Color(0xFF121212);
const cSurface2 = Color(0xFF181818);
const cLine = Color(0xFF262626);
const cGreen = Color(0xFF00FF66);
const cAmber = Color(0xFFFFCC00);
const cCoral = Color(0xFFFF5555);
const cDim = Color(0xFF8A8A8A);
const mono = 'monospace';

ThemeData fitaiTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: cBg,
      primaryColor: cGreen,
      colorScheme: const ColorScheme.dark(
        primary: cGreen, secondary: cAmber, error: cCoral, surface: cSurface,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: cGreen, thumbColor: cGreen, inactiveTrackColor: cLine,
      ),
    );
