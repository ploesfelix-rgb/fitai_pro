// lib/state/app_state.dart
//
// Estado global reactivo (ChangeNotifier). Interconecta los 6 modulos.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as d;

class AppState extends ChangeNotifier {
  final FitAiDb db;
  AppState(this.db);

  // sesion / onboarding
  bool signedIn = false;
  bool onboarded = false;

  // perfil
  double weight = 82, height = 178, targetWeight = 0;
  int age = 28;
  String sex = 'male';
  double activity = 1.55;
  String goal = 'cut';
  DateTime? targetDate;

  // fisico
  bool hasCompletedPhysicalDiagnosis = false;
  double bodyFat = 22;
  Map<String, double> metrics = {
    'chest': 0.42, 'abadipose': 0.28, 'scapular': 1.02,
    'delt': 0.35, 'lat': 0.38, 'symmetry': 0.80,
  };
  List<String> priorityFix = [];

  // nutricion (consumo de hoy en memoria; historial en BD)
  double cK = 0, cP = 0, cC = 0, cF = 0;
  String? viewDate;

  // gym
  int session = 0;
  DateTime? lastTrained;
  String? cardioFatigueZone;

  static const kcalPerKg = 7700.0;

  int daysUntil() =>
      targetDate == null ? 84 : targetDate!.difference(DateTime.now()).inDays.clamp(0, 99999);
  double weightGap() => targetWeight == 0 ? 0 : weight - targetWeight;
  double perWeek() {
    if (targetWeight == 0) return goal == 'cut' ? -0.5 : 0.15;
    final weeks = (daysUntil() / 7).clamp(1, 999).toDouble();
    final pw = (targetWeight - weight) / weeks;
    final maxW = weight * 0.01;
    return pw.clamp(-maxW, maxW);
  }

  double bmr() => sex == 'male'
      ? 88.362 + 13.397 * weight + 4.799 * height - 5.677 * age
      : 447.593 + 9.247 * weight + 3.098 * height - 4.330 * age;
  double tdee() => bmr() * activity;

  bool trainedToday() {
    if (lastTrained == null) return false;
    final n = DateTime.now();
    return lastTrained!.year == n.year && lastTrained!.month == n.month && lastTrained!.day == n.day;
  }

  Map<String, int> todayTarget() {
    var kcal = tdee() + perWeek() * kcalPerKg / 7;
    final swing = tdee() * 0.10;
    kcal += trainedToday() ? swing : -swing;
    final p = (perWeek() < 0 ? 2.3 : 2.0) * weight;
    final f = (kcal * 0.25) / 9;
    final c = ((kcal - p * 4 - f * 9) / 4).clamp(0, 99999).toDouble();
    return {'kcal': kcal.round(), 'p': p.round(), 'c': c.round(), 'f': f.round()};
  }

  String dateKey([DateTime? dt]) {
    final x = dt ?? DateTime.now();
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveToday() async {
    final t = todayTarget();
    await db.into(db.nutritionDays).insertOnConflictUpdate(
          NutritionDaysCompanion.insert(
            dateKey: dateKey(),
            kcal: d.Value(cK),
            protein: d.Value(cP),
            carbs: d.Value(cC),
            fat: d.Value(cF),
            targetKcal: d.Value(t['kcal']!.toDouble()),
            targetProtein: d.Value(t['p']!.toDouble()),
            logged: d.Value(cK > 0),
          ),
        );
    notifyListeners();
  }

  Future<List<double>?> dayRecord(String key) async {
    final row = await (db.select(db.nutritionDays)..where((r) => r.dateKey.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return [row.kcal, row.protein, row.carbs, row.fat, row.targetKcal, row.targetProtein, row.logged ? 1 : 0];
  }

  Future<void> addFood(double kcal, double p, double c, double f) async {
    cK += kcal; cP += p; cC += c; cF += f; viewDate = null;
    await saveToday();
  }

  Future<void> completeDiagnosis(Map<String, double> m, double fat) async {
    metrics = m; bodyFat = fat;
    hasCompletedPhysicalDiagnosis = true;
    await db.into(db.bodyMetrics).insert(BodyMetricsCompanion.insert(
          dateIso: DateTime.now().toIso8601String(),
          bodyFat: fat,
          chestRatio: m['chest']!,
          abAdipose: m['abadipose']!,
          scapularWidth: m['scapular']!,
          deltRelief: m['delt']!,
          latSpread: m['lat']!,
          symmetry: m['symmetry']!,
        ));
    notifyListeners();
  }

  String focusMetric() {
    final maxes = {'chest': 1.0, 'scapular': 1.4, 'delt': 1.0, 'lat': 1.0, 'symmetry': 1.0};
    String low = 'delt';
    double lv = 999;
    maxes.forEach((k, mx) {
      final rel = (metrics[k] ?? 0) / mx;
      if (rel < lv) { lv = rel; low = k; }
    });
    return low;
  }

  void togglePriority(String k) {
    priorityFix.contains(k) ? priorityFix.remove(k) : priorityFix.add(k);
    notifyListeners();
  }

  // LOG OUT seguro: tokens + wipe BD cifrada + borrado de cache de archivos
  Future<void> logout() async {
    signedIn = false;
    hasCompletedPhysicalDiagnosis = false;
    cK = cP = cC = cF = 0;
    session = 0;
    lastTrained = null;
    priorityFix.clear();
    cardioFatigueZone = null;
    await db.wipeAll();
    try {
      final cache = await getTemporaryDirectory();
      if (await cache.exists()) {
        await for (final e in cache.list()) {
          await e.delete(recursive: true);
        }
      }
    } catch (_) {}
    // NATIVO: invalidar token de Google/OTP en su SDK respectivo
    notifyListeners();
  }
}
