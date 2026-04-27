import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'session_helper.dart';
import 'widgets/ecrono_bottom_navigation.dart';

class AppNavigation {
  static Future<void> irAInicio(BuildContext context) async {
    final String? role = await SessionHelper.getRole();

    if (!context.mounted) {
      return;
    }

    final String routeName = role == 'caregiver'
        ? AppRoutes.cuidador
        : AppRoutes.paciente;

    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => route.isFirst,
    );
  }

  static void abrirSalud(BuildContext context, {bool reemplazar = false}) {
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
}
