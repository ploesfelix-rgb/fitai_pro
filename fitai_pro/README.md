# FitAI — Proyecto Flutter de producción (arquitectura modular)

App nativa Flutter con los 6 módulos del brief, arquitectura limpia multi-archivo,
estado global reactivo (`ChangeNotifier` + `provider`), SQLite cifrado (Drift +
SQLCipher), cámara real, dictado por voz, cliente Dio y notificaciones locales.

## Árbol de archivos

```
fitai_pro/
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml   # permisos cámara/micro/internet/notif; allowBackup=false
├── ios/Runner/Info.plist                       # NSCamera/NSMicrophone/NSSpeech UsageDescription; modo oscuro
└── lib/
    ├── main.dart                  # arranque + navegación por pestañas + Gate
    ├── core/
    │   ├── theme.dart             # colores de marca + tema oscuro
    │   ├── api_client.dart        # Modulo 1: Dio, interceptores, timeouts 5000ms, 404/500
    │   ├── food_api_client.dart   # Reconocimiento nutricional: Dio, multipart, timeout 6000ms
    │   ├── biometric_engine.dart  # Modulo 3: ML Kit Pose Detection LOCAL + metricas
    │   └── notifications.dart     # Modulo 6: notificaciones locales + modo descanso
    ├── data/
    │   ├── database.dart          # Modulo 3: Drift + SQLCipher; wipeAll() atómico
    │   ├── database.g.dart        # GENERADO por build_runner (no incluido; ver abajo)
    │   └── food_repository.dart   # orquesta API comida -> estado/BD -> borra imagen + Smart Coach
    ├── state/
    │   └── app_state.dart         # estado global: lógica nutricional, gym, logout
    ├── widgets/
    │   ├── ui.dart                # helpers (bracketButton, card, banners)
    │   ├── pose_overlay.dart      # mascara/esqueleto verde sobre la camara
    │   └── flip_card.dart         # tarjeta muscular con flip 3D + (?) + PRIORIZAR
    └── screens/
        ├── login_screen.dart      # OAuth Google / OTP (simulado)
        ├── onboarding_screen.dart # Modulo 2: wizard + diagnóstico biométrico
        ├── body_screen.dart       # Modulo 3: cámara en vivo + pose local + borrado atómico
        ├── food_scan_screen.dart  # Escáner de comida: cámara + bottom sheet + Smart Coach + failsafe manual
        ├── home_screen.dart       # Modulo 4: anillo de macros + calendario histórico
        ├── gym_screen.dart        # Modulo 5: one-button, doble progresión, voz, failsafe red
        └── profile_screen.dart    # Modulo 6: log out seguro
```

## Configuración nativa que exige ML Kit (importante)

`google_mlkit_pose_detection` necesita ajustes en los proyectos nativos, o no
compila / no arranca:

- **Android**: `minSdkVersion 21` (o superior) en `android/app/build.gradle`.
  ML Kit descarga su modelo; deja la primera ejecución con red disponible.
- **iOS**: `platform :ios, '15.5'` en `ios/Podfile` (ML Kit exige iOS 15.5+),
  luego `cd ios && pod install`. Compilar en un dispositivo real (los modelos de
  ML Kit no funcionan bien en algunos simuladores).

## Puesta en marcha

```
flutter create . --org com.fitai --project-name fitai   # genera runners nativos
flutter pub get
dart run build_runner build --delete-conflicting-outputs # GENERA database.g.dart (imprescindible)
flutter run                                              # dispositivo conectado
```

El paso `build_runner` es obligatorio: `database.dart` declara `part 'database.g.dart'`
y ese archivo lo genera Drift. Sin él, no compila.

## Comandos de build

```
flutter clean
flutter build apk --release     # Android -> build/app/outputs/flutter-apk/app-release.apk
flutter build ipa --release     # iOS (requiere macOS + Xcode + cuenta Apple)
```

## Reconocimiento de comida: configuración de la clave (CRÍTICO)

El escáner de comida (`food_api_client.dart`) está listo, pero **no funcionará hasta
que conectes un endpoint real**, y hay un punto de seguridad que no puedes saltarte:

- **NO escribas la clave de LogMeal/Spoonacular en el código.** Cualquiera puede
  extraerla del `.apk` y gastar tu cuota (estas APIs cobran por uso). Es el mismo
  error de la clave de Gemini expuesta en la versión web.
- **Forma correcta a escala** ("para todos los usuarios"): la app llama a TU backend,
  y tu backend guarda la clave y llama a LogMeal. Pon la URL de tu backend en
  `_endpoint`. Así la clave nunca viaja en la app.
- Mientras no conectes un endpoint real, el escáner caerá siempre al **failsafe de
  entrada manual** (que funciona: introduces los macros a mano y se suman al día).

Esto es deliberado: prefiero que el escáner caiga limpiamente a manual antes que
enseñarte a incrustar una clave que te expondría a un cargo económico.

## Nota de honestidad técnica (importante)

No he ejecutado `flutter build` sobre este código: el entorno donde se generó no
tiene el SDK de Flutter ni red. He validado la estructura (balance de delimitadores,
imports, errores típicos de `const`/tipos), pero **un proyecto que integra cámara +
Drift con generación de código + Dio + speech_to_text casi siempre requiere algún
ajuste en la primera compilación real** (versiones de paquete, configuración de
Gradle mínima de SDK para `camera`, permisos en runtime). Trátalo como "listo para
`flutter run` y depurar", no como un binario ya probado.

Qué es real y qué es stub:
- **Real**: arquitectura, estado reactivo, lógica matemática (tasa de peso, anillo
  dinámico, doble progresión, fatiga), SQLite cifrado con Drift+SQLCipher, borrado
  atómico (`wipeAll` + `File.delete` de la foto), cámara en vivo, navegación, UI, y
  el **escáner biométrico local**: ML Kit detecta de verdad los 33 landmarks del
  esqueleto, valida hombros/cadera/rodillas, y rechaza la foto si no los encuentra.
- **Honestidad sobre las métricas del escáner**: de la pose se miden proporciones
  óseas REALES (anchura de hombros, ratio hombro/cadera en forma de V, simetría
  izquierda/derecha, longitud de tronco). Pero "% de grasa", "relieve de deltoides"
  y similares NO son medibles desde landmarks de pose: se derivan por **heurística**
  a partir de esas proporciones y la pantalla lo indica. No es una medición clínica.
  Para composición corporal real haría falta otro sensor o un modelo entrenado
  específicamente, no pose detection.
- **Stub / por completar** (marcado `// NATIVO:`):
  - Login Google/OTP simulado (integra Firebase Auth).
  - Push remotas (aquí son notificaciones **locales**; para APNs/FCM + WorkManager
    falta la capa de servidor).
  - El parseo del dictado por voz a kg/reps está como gancho, sin el parser final.
  - `api_client.dart` (Dio) queda para el módulo 1 (ExerciseDB / imágenes del gym).

Sobre privacidad: el cifrado de la base de datos con SQLCipher **sí es real** en
esta versión (la clave vive en Keychain/Keystore). La foto se borra del disco con
`File.delete()` en un bloque `finally`, pase lo que pase con el análisis.
