import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../api_constants.dart';
import '../session_helper.dart';
import 'offline_vital_signs_service.dart';

class ConnectivitySyncService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool? _teniaConexion;
  static bool _sincronizando = false;

  static void iniciarListener() {
    if (_subscription != null) {
      return;
    }

    unawaited(_configurarListener());
  }

  static Future<void> _configurarListener() async {
    try {
      final List<ConnectivityResult> estadoInicial = await _connectivity
          .checkConnectivity();
      _teniaConexion = _tieneConexion(estadoInicial);

      _subscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> resultados,
      ) {
        final bool tieneConexion = _tieneConexion(resultados);
        final bool conexionRecuperada =
            _teniaConexion == false && tieneConexion;
        _teniaConexion = tieneConexion;

        if (conexionRecuperada) {
          unawaited(_sincronizarPendientes());
        }
      }, onError: (_) {});
    } catch (_) {
      _teniaConexion = null;
    }
  }

  static bool _tieneConexion(List<ConnectivityResult> resultados) {
    return resultados.any((resultado) => resultado != ConnectivityResult.none);
  }

  static Future<void> _sincronizarPendientes() async {
    if (_sincronizando) {
      return;
    }

    _sincronizando = true;

    try {
      final List<Map<String, dynamic>> registrosPendientes =
          await OfflineVitalSignsService.obtenerRegistrosPendientes();

      for (final Map<String, dynamic> registro in registrosPendientes) {
        if (registro['is_demo'] == 'true') {
          continue;
        }

        final String? localId = registro['local_id']?.toString().trim();
        if (localId == null || localId.isEmpty) {
          continue;
        }

        final bool sincronizado = await _enviarRegistroPendiente(registro);
        if (!sincronizado) {
          continue;
        }

        await OfflineVitalSignsService.eliminarRegistroPendiente(localId);
      }
    } catch (_) {
      // El listener no debe propagar errores hacia la app.
    } finally {
      _sincronizando = false;
    }
  }

  static Future<bool> _enviarRegistroPendiente(
    Map<String, dynamic> registroPendiente,
  ) async {
    try {
      final Map<String, dynamic> datosRegistro = Map<String, dynamic>.from(
        registroPendiente,
      );
      datosRegistro.remove('local_id');
      datosRegistro.remove('created_at_local');
      datosRegistro.remove('sync_status');
      datosRegistro.remove('estado_sincronizacion');
      datosRegistro.remove('is_demo');

      final response = await SessionHelper.authenticatedPost(
        Uri.parse(apiVitalSignRecordsUrl),
        body: jsonEncode(datosRegistro),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
