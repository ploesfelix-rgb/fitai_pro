// lib/core/notifications.dart
//
// Modulo 6: Smart Push Engine con notificaciones locales programadas.
// Respeta el Modo Descanso nocturno (no programa entre 22:00 y 07:00).
// NATIVO: para push remotas reales se anade Firebase/APNs + WorkManager.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  bool _restMode() {
    final h = DateTime.now().hour;
    return h >= 22 || h < 7; // modo descanso nocturno
  }

  Future<void> show(int id, String title, String body) async {
    if (_restMode()) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails('fitai_default', 'FitAI',
          importance: Importance.defaultImportance, priority: Priority.defaultPriority),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  // textos contextuales (sin emojis)
  Future<void> nutritionReminder() => show(1, 'FitAI Nutricion',
      'Falta registro de almuerzo. Por favor, haga clic aqui para iniciar el escaner de video y comprobar tus proteinas de hoy.');

  Future<void> gymReminder() => show(2, 'FitAI Coach',
      'Su entrenamiento bajo demanda esta listo. El algoritmo calcula una meta de progresion en peso o repeticiones para su sesion de hoy. Inicie el calculo aqui.');

  Future<void> macrosAlert(int pendingProtein) => show(3, 'Alerta FitAI',
      'Te faltan $pendingProtein g de proteina hoy. Consume una cena limpia para proteger tu musculo mientras sigues bajando de peso.');
}
