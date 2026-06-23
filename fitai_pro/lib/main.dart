// lib/main.dart
//
// Arranque de FitAI: abre la BD cifrada, inyecta el estado global (Provider),
// inicializa notificaciones y monta la navegacion por pestanas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/notifications.dart';
import 'data/database.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/body_screen.dart';
import 'screens/gym_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = FitAiDb(openEncrypted());
  await Notifications.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(db),
      child: const FitAiApp(),
    ),
  );
}

class FitAiApp extends StatelessWidget {
  const FitAiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitAI',
      debugShowCheckedModeBanner: false,
      theme: fitaiTheme(),
      home: const Gate(),
    );
  }
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.signedIn) return const LoginScreen();
    if (!st.onboarded) return const OnboardingScreen();
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final _labels = const ['INICIO', 'FISICO', 'GYM', 'YO'];

  Widget _screen() {
    switch (_tab) {
      case 1:
        return const BodyScreen();
      case 2:
        return const GymScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(bottom: false, child: _screen()),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: cSurface,
          border: Border(top: BorderSide(color: cLine)),
        ),
        padding: const EdgeInsets.only(bottom: 18, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (i) {
            final on = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(_labels[i],
                    style: TextStyle(
                        fontFamily: mono, fontSize: 11, fontWeight: FontWeight.w800,
                        color: on ? cGreen : cDim)),
              ),
            );
          }),
        ),
      ),
    );
  }
}
