import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'route_observer.dart';
import 'screens/pantalla_ajustes.dart';
import 'screens/pantalla_calendario_controles.dart';
import 'screens/pantalla_editar_perfil.dart';
import 'screens/pantalla_inicial.dart';
import 'screens/pantalla_mis_registros.dart';
import 'screens/pantalla_pendientes.dart';
import 'screens/pantalla_registrar_signos_vitales.dart';
import 'theme/app_theme.dart';
import 'screens/vista_cuidador.dart';
import 'screens/vista_paciente.dart';

void main() {
  runApp(const ECronoApp());
}

// Widget principal de la aplicacion.
class ECronoApp extends StatelessWidget {
  const ECronoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'e-Crono',
      theme: AppTheme.lightTheme,
      navigatorObservers: [routeObserver],
      home: const PantallaInicial(),
      routes: {
        AppRoutes.paciente: (_) => const VistaPaciente(),
        AppRoutes.cuidador: (_) => const VistaCuidador(),
        AppRoutes.salud: (_) => const PantallaRegistrarSignosVitales(),
        AppRoutes.pendientes: (_) => const PantallaPendientes(),
        AppRoutes.ajustes: (_) => const PantallaAjustes(),
        AppRoutes.editarPerfil: (_) => const PantallaEditarPerfil(),
        AppRoutes.misRegistros: (_) => const PantallaMisRegistros(),
        AppRoutes.calendarioControles: (_) =>
            const PantallaCalendarioControles(),
      },
    );
  }
}
