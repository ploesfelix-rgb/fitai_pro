// lib/core/api_client.dart
//
// Modulo 1: cliente HTTP centralizado (Dio) con interceptores y timeouts.
// Consulta bases de datos de ejercicios e imagenes, y envia peticiones de vision.

import 'dart:typed_data';
import 'package:dio/dio.dart';

class ApiResult {
  final bool ok;
  final int status;
  final dynamic data;
  final String? error;
  ApiResult({required this.ok, required this.status, this.data, this.error});
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 5000),
    receiveTimeout: const Duration(milliseconds: 5000),
    sendTimeout: const Duration(milliseconds: 5000),
  ))
    ..interceptors.add(InterceptorsWrapper(
      onResponse: (res, handler) => handler.next(res),
      onError: (err, handler) {
        // Centraliza el manejo de 404/500/timeout sin reventar la UI
        handler.next(err);
      },
    ));

  /// Descarga metadatos/URL de imagen de un ejercicio (failsafe en la UI).
  Future<ApiResult> exerciseMedia(String slug) async {
    try {
      final res = await _dio.get(
        'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$slug/0.jpg',
        options: Options(responseType: ResponseType.bytes),
      );
      return ApiResult(ok: res.statusCode == 200, status: res.statusCode ?? 0, data: res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      return ApiResult(ok: false, status: code, error: _msg(e));
    } catch (e) {
      return ApiResult(ok: false, status: 0, error: e.toString());
    }
  }

  /// Envia los bytes de la foto al servicio de vision para validar y analizar.
  /// NOTA: endpoint de ejemplo. Sustituir por el servicio real de FitAI.
  Future<ApiResult> analyzeBodyPhoto(Uint8List bytes) async {
    try {
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: 'scan.jpg'),
      });
      final res = await _dio.post(
        'https://api.fitai.example/v1/vision/body',
        data: form,
      );
      return ApiResult(ok: res.statusCode == 200, status: res.statusCode ?? 0, data: res.data);
    } on DioException catch (e) {
      return ApiResult(ok: false, status: e.response?.statusCode ?? 0, error: _msg(e));
    }
  }

  String _msg(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'timeout';
      case DioExceptionType.connectionError:
        return 'sin_conexion';
      default:
        final s = e.response?.statusCode ?? 0;
        if (s == 404) return 'no_encontrado';
        if (s >= 500) return 'error_servidor';
        return 'error_red';
    }
  }
}
