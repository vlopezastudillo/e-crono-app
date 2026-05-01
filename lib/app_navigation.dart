import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'screens/pantalla_mis_registros.dart';
import 'screens/pantalla_registrar_signos_vitales.dart';
import 'session_helper.dart';
import 'widgets/ecrono_bottom_navigation.dart';

class AppNavigation {
  static Future<void> irAInicio(BuildContext context) async {
    final String? role = await SessionHelper.getRole();

    if (!context.mounted) {
      return;
    }

    final String routeName = _esRolCuidador(role)
        ? AppRoutes.cuidador
        : AppRoutes.paciente;

    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }

  static void abrirSalud(
    BuildContext context, {
    bool reemplazar = false,
    int? patientId,
    String? patientName,
  }) {
    if (patientId != null) {
      final route = MaterialPageRoute(
        builder: (_) => PantallaRegistrarSignosVitales(
          patientId: patientId,
          patientName: patientName,
        ),
      );

      if (reemplazar) {
        Navigator.pushReplacement(context, route);
        return;
      }

      Navigator.push(context, route);
      return;
    }

    _abrirSeccion(context, AppRoutes.salud, reemplazar: reemplazar);
  }

  static void abrirPendientes(BuildContext context, {bool reemplazar = false}) {
    _abrirSeccion(context, AppRoutes.pendientes, reemplazar: reemplazar);
  }

  static void abrirAjustes(BuildContext context, {bool reemplazar = false}) {
    _abrirSeccion(context, AppRoutes.ajustes, reemplazar: reemplazar);
  }

  static void abrirEditarPerfil(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.editarPerfil);
  }

  static void abrirMisRegistros(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.misRegistros);
  }

  static void abrirRegistrosPaciente(
    BuildContext context, {
    required int patientId,
    required String patientName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaMisRegistros(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  static void abrirCalendarioControles(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.calendarioControles);
  }

  static void manejarBarraInferior(
    BuildContext context, {
    required EcronoBottomSection actual,
    required EcronoBottomSection destino,
  }) {
    if (actual == destino) {
      return;
    }

    switch (destino) {
      case EcronoBottomSection.inicio:
        irAInicio(context);
        break;
      case EcronoBottomSection.salud:
        abrirSalud(context, reemplazar: actual != EcronoBottomSection.inicio);
        break;
      case EcronoBottomSection.pendientes:
        abrirPendientes(
          context,
          reemplazar: actual != EcronoBottomSection.inicio,
        );
        break;
      case EcronoBottomSection.ajustes:
        abrirAjustes(context, reemplazar: actual != EcronoBottomSection.inicio);
        break;
    }
  }

  static void _abrirSeccion(
    BuildContext context,
    String routeName, {
    required bool reemplazar,
  }) {
    if (reemplazar) {
      Navigator.pushReplacementNamed(context, routeName);
      return;
    }

    Navigator.pushNamed(context, routeName);
  }

  static bool _esRolCuidador(String? role) {
    final String roleNormalizado = role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }
}
