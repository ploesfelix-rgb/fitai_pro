// lib/data/food_repository.dart
//
// Capa de repositorio del modulo nutricional: orquesta API -> estado -> BD,
// y borra la imagen del disco tras guardar los macros (volatilidad inmediata).

import 'dart:io';
import '../core/food_api_client.dart';
import '../state/app_state.dart';

class FoodLogResult {
  final bool ok;
  final FoodAnalysis? analysis;
  final String? coachAdvice; // consejo del Smart Coach (puede ser null)
  final String? failReason;
  FoodLogResult({required this.ok, this.analysis, this.coachAdvice, this.failReason});
}

class FoodRepository {
  final AppState state;
  FoodRepository(this.state);

  /// Analiza la foto, inyecta macros en el estado/BD, borra la imagen y
  /// devuelve el desglose + consejo. Si falla, devuelve el motivo (failsafe).
  Future<FoodLogResult> logMealFromPhoto(String imagePath) async {
    final res = await FoodApiClient.instance.analyzeMeal(imagePath);

    // VOLATILIDAD INMEDIATA: borrar la imagen pase lo que pase con el analisis
    try {
      final f = File(imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    if (!res.ok || res.data == null) {
      return FoodLogResult(ok: false, failReason: res.failReason);
    }
    final a = res.data!;

    // sincronizacion automatica con el dia de hoy (resta del presupuesto)
    await state.addFood(a.calories, a.proteinsG, a.carbsG, a.fatsG);

    return FoodLogResult(
      ok: true,
      analysis: a,
      coachAdvice: _advice(a),
    );
  }

  /// Logica predictiva del Smart Coach segun macros y objetivo del usuario.
  String? _advice(FoodAnalysis a) {
    // proteina considerada baja si aporta <25% de las kcal del plato
    final protKcal = a.proteinsG * 4;
    final lowProtein = a.calories > 0 && (protKcal / a.calories) < 0.25;
    final wantsMuscle = state.goal == 'bulk' || state.goal == 'cut';

    if (lowProtein && wantsMuscle) {
      return 'FitAI Coach: Este plato contiene niveles bajos de proteina para tu '
          'objetivo. Para mantener el balance calorico de hoy en ruta hacia tu peso '
          'objetivo, te recomendamos complementar tu siguiente ingesta anadiendo '
          '150g de pechuga de pollo o una fuente de proteina limpia.';
    }
    // si va sobrado de proteina, refuerzo positivo breve
    if (!lowProtein && a.proteinsG > 0) {
      return 'FitAI Coach: Buen aporte proteico en este plato. Mantienes el balance '
          'adecuado para preservar masa muscular en tu trayectoria de hoy.';
    }
    return null;
  }
}
