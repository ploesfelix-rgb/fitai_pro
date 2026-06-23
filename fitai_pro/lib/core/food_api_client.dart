// lib/core/food_api_client.dart
//
// Capa de servicio de red para el reconocimiento nutricional (Food AI Vision).
// Cliente Dio centralizado: headers de produccion, Bearer token, timeout 6000ms,
// envio multipart (FormData) y captura de errores hacia el failsafe manual.
//
// =====================  AVISO DE SEGURIDAD (LEER)  =====================
// NUNCA escribas la clave real de LogMeal/Spoonacular aqui en una app de
// produccion: cualquiera puede extraerla del .apk y gastar tu cuota / tu dinero.
//
// Forma correcta a escala (recomendada):
//   La app llama a TU backend  ->  tu backend guarda la clave y llama a LogMeal.
//   Asi la clave nunca viaja en la app.  Pon aqui la URL de tu backend.
//
// Solo para pruebas locales y bajo tu propio riesgo puedes apuntar directo a la
// API y poner la clave en _apiKey. Si lo haces, revoca esa clave despues.
// ======================================================================

import 'dart:io';
import 'package:dio/dio.dart';

class FoodAnalysis {
  final String foodName;
  final double estimatedWeightG;
  final double calories;
  final double proteinsG;
  final double carbsG;
  final double fatsG;
  FoodAnalysis({
    required this.foodName,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinsG,
    required this.carbsG,
    required this.fatsG,
  });

  factory FoodAnalysis.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return FoodAnalysis(
      foodName: (j['food_name'] ?? j['name'] ?? 'Plato no identificado').toString(),
      estimatedWeightG: n(j['estimated_weight_g'] ?? j['serving_size']),
      calories: n(j['calories'] ?? j['nutrition']?['calories']),
      proteinsG: n(j['proteins_g'] ?? j['nutrition']?['protein']),
      carbsG: n(j['carbs_g'] ?? j['nutrition']?['carbs']),
      fatsG: n(j['fats_g'] ?? j['nutrition']?['fat']),
    );
  }
}

/// Resultado tipado: exito con datos, o fallo con motivo (para el failsafe).
class FoodResult {
  final bool ok;
  final FoodAnalysis? data;
  final String? failReason;
  FoodResult.success(this.data) : ok = true, failReason = null;
  FoodResult.failure(this.failReason) : ok = false, data = null;
}

class FoodApiClient {
  FoodApiClient._();
  static final FoodApiClient instance = FoodApiClient._();

  // ---- CONFIGURACION: rellena con TU worker de Cloudflare ----
  // Tras desplegar el worker, pega aqui su URL + la ruta del endpoint:
  //   https://fitai-food-proxy.TU-USUARIO.workers.dev/api/v1/food-analysis
  // El worker guarda la clave de Gemini en secreto; la app NO lleva ninguna clave.
  static const String _endpoint =
      'https://fitai-food-proxy.TU-USUARIO.workers.dev/api/v1/food-analysis';
  static const String _apiKey = ''; // <- vacio: la clave vive en el worker, no aqui

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 6000),
    receiveTimeout: const Duration(milliseconds: 6000),
    sendTimeout: const Duration(milliseconds: 6000),
    headers: {
      'Content-Type': 'application/json',
      if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
    },
  ))
    ..interceptors.add(InterceptorsWrapper(
      onError: (e, handler) => handler.next(e), // se gestiona arriba
    ));

  /// Comprime y envia la imagen del plato. Devuelve datos o motivo de fallo.
  /// Concurrencia: Dio maneja peticiones simultaneas; cada llamada es independiente,
  /// asi que miles de usuarios pueden enviar en paralelo sin bloquearse entre si.
  Future<FoodResult> analyzeMeal(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return FoodResult.failure('No se encontro la imagen capturada.');
      }
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath, filename: 'meal.jpg'),
        'lang': 'es', // nombres de plato en espanol
      });

      final res = await _dio.post(_endpoint, data: form);
      if (res.statusCode == 200 && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data);
        // el worker devuelve ok:false en fallos controlados (timeout, mala imagen)
        if (map['ok'] == false) {
          return FoodResult.failure('No se pudo identificar el plato. Introduce los datos a mano.');
        }
        return FoodResult.success(FoodAnalysis.fromJson(map));
      }
      return FoodResult.failure('El servicio no pudo identificar el plato.');
    } on DioException catch (e) {
      // failsafe: red caida, timeout o error de servidor -> entrada manual
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return FoodResult.failure('El analisis tardo demasiado. Introduce los datos a mano.');
        case DioExceptionType.connectionError:
          return FoodResult.failure('Sin conexion. Introduce los datos a mano.');
        default:
          return FoodResult.failure('No se pudo analizar el plato. Introduce los datos a mano.');
      }
    } catch (_) {
      return FoodResult.failure('Error inesperado. Introduce los datos a mano.');
    }
  }
}
