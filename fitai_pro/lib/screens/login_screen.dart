// lib/screens/login_screen.dart
// Login OAuth Google / OTP. NATIVO: integrar Firebase Auth / proveedor OTP real.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return Scaffold(
      backgroundColor: cBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 66, height: 66, alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [cGreen, Color(0xFF00CC52)]),
              ),
              child: const Text('F',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF06140C))),
            ),
            const SizedBox(height: 14),
            const Text('FitAI',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('Tu evolucion fisica calculada por FitAI',
                style: TextStyle(fontSize: 13, color: cDim)),
            const SizedBox(height: 44),
            bracketButton('[ CONTINUAR CON GOOGLE ]', () {
              st.signedIn = true; st.notifyListeners();
            }),
            const SizedBox(height: 12),
            bracketButton('[ VALIDAR CON TELEFONO (OTP) ]', () {
              st.signedIn = true; st.notifyListeners();
            }, color: cAmber),
            const SizedBox(height: 18),
            const Text('Demo: el acceso con Google y el SMS estan simulados en esta version.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cDim, height: 1.5)),
          ]),
        ),
      ),
    );
  }
}
