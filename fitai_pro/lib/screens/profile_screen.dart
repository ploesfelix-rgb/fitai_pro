// lib/screens/profile_screen.dart
// Modulo 6: perfil + log out seguro (wipe atomico + redireccion a login).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _confirm(BuildContext context, AppState st) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cSurface,
        title: const Text('Cerrar sesion de FitAI',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
            'Al salir se eliminaran de forma permanente la telemetria local, el cache '
            'y las tablas cifradas de la base de datos. Tu plan se recalculara al volver.',
            style: TextStyle(color: cDim, height: 1.5, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(fontFamily: mono, color: cDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await st.logout();
            },
            child: const Text('CERRAR SESION', style: TextStyle(fontFamily: mono, color: cCoral)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        sectionTitle('PERFIL'),
        const SizedBox(height: 16),
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DATOS FISICOS BASE',
                style: TextStyle(fontFamily: mono, fontSize: 11, color: cGreen)),
            const SizedBox(height: 10),
            _row('Peso actual', '${st.weight.toStringAsFixed(0)} kg'),
            _row('Altura', '${st.height.toStringAsFixed(0)} cm'),
            _row('Peso objetivo', '${st.targetWeight.toStringAsFixed(0)} kg'),
            _row('Objetivo', st.goal == 'cut' ? 'Definicion' : 'Volumen'),
            _row('Ritmo', '${st.perWeek().toStringAsFixed(2)} kg/sem'),
          ]),
        ),
        const SizedBox(height: 14),
        bracketButton('[ CERRAR SESION DE FITAI ]', () => _confirm(context, st), color: cCoral),
      ],
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: cDim, fontSize: 13)),
          Text(v, style: const TextStyle(fontFamily: mono, color: Colors.white, fontSize: 13)),
        ]),
      );
}
