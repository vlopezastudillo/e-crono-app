import 'package:flutter/material.dart';

import 'screens/pantalla_inicial.dart';
import 'session_helper.dart';

Future<void> handleSessionExpired(
  BuildContext context, {
  SessionExpiredException? error,
}) async {
  await SessionHelper.clearSession();

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          error?.message ?? 'Tu sesión expiró. Inicia sesión nuevamente.',
        ),
      ),
    );

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const PantallaInicial()),
    (route) => false,
  );
}
