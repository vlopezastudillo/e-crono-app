import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineVitalSignsService {
  static const String _keyRegistrosPendientes =
      'offline_vital_signs_pending_records';

  static Future<bool> guardarRegistroPendiente(
    Map<String, dynamic> registro,
  ) async {
    try {
      final String? localId = registro['local_id']?.toString().trim();
      if (localId == null || localId.isEmpty) {
        return false;
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> registros = _leerRegistrosPendientes(
        prefs,
      );

      final bool yaExiste = registros.any(
        (item) => item['local_id']?.toString() == localId,
      );
      if (yaExiste) {
        return false;
      }

      final Map<String, dynamic> registroPendiente = {
        ...registro,
        'local_id': localId,
        'created_at_local':
            registro['created_at_local']?.toString() ??
            DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      };

      registros.add(registroPendiente);
      return prefs.setString(_keyRegistrosPendientes, jsonEncode(registros));
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerRegistrosPendientes() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return _leerRegistrosPendientes(prefs);
    } catch (_) {
      return [];
    }
  }

  static Future<bool> eliminarRegistroPendiente(String localId) async {
    try {
      final String localIdLimpio = localId.trim();
      if (localIdLimpio.isEmpty) {
        return false;
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> registros = _leerRegistrosPendientes(
        prefs,
      );
      final int cantidadInicial = registros.length;

      registros.removeWhere(
        (item) => item['local_id']?.toString() == localIdLimpio,
      );

      if (registros.length == cantidadInicial) {
        return false;
      }

      return prefs.setString(_keyRegistrosPendientes, jsonEncode(registros));
    } catch (_) {
      return false;
    }
  }

  static Future<int> contarRegistrosPendientes() async {
    try {
      final List<Map<String, dynamic>> registros =
          await obtenerRegistrosPendientes();
      return registros.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> limpiarDatosDemo() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();

      for (final String key in keys) {
        final String? raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) {
          continue;
        }

        try {
          final dynamic data = jsonDecode(raw);
          if (data is! List) {
            continue;
          }

          final int cantidadOriginal = data.length;
          final List<dynamic> registrosLimpios = data.where((item) {
            if (item is! Map) {
              return true;
            }

            final dynamic rawPatientId =
                item['patient_id'] ?? item['patientId'] ?? item['patient'];
            final int? patientId = int.tryParse(rawPatientId?.toString() ?? '');

            return patientId != 101 && patientId != 102;
          }).toList();

          final int eliminados = cantidadOriginal - registrosLimpios.length;
          if (eliminados > 0) {
            await prefs.setString(key, jsonEncode(registrosLimpios));
          }
        } catch (_) {
          // Ignora keys que no contienen JSON válido.
        }
      }
    } catch (_) {
      // La limpieza no debe impedir que la app inicie.
    }
  }

  static List<Map<String, dynamic>> _leerRegistrosPendientes(
    SharedPreferences prefs,
  ) {
    final String? registrosJson = prefs.getString(_keyRegistrosPendientes);
    if (registrosJson == null || registrosJson.isEmpty) {
      return [];
    }

    final dynamic data = jsonDecode(registrosJson);
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
