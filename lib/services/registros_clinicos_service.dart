import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_constants.dart';
import '../session_helper.dart';

class RegistrosClinicosService {
  const RegistrosClinicosService();

  Future<List<Map<String, String>>> cargarMisRegistros() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return [];
      }

      final response = await http.get(
        Uri.parse(apiVitalSignRecordsUrl),
        headers: headers,
      );

      debugPrint('GET mis registros: estado HTTP ${response.statusCode}');
      debugPrint('GET mis registros: respuesta ${response.body}');

      if (response.statusCode != 200) {
        return [];
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items;

      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic> && data['results'] is List) {
        items = data['results'] as List<dynamic>;
      } else {
        return [];
      }

      final List<Map<String, dynamic>> registros = items
          .whereType<Map<String, dynamic>>()
          .toList();

      registros.sort(_compararRegistrosPorFechaDescendente);

      return registros.map(_mapearRegistro).toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, String>> obtenerRegistrosDemoPaciente() {
    return const [
      {
        'patient': 'Paciente demo',
        'fecha': '24/04/2026',
        'presion_sistolica': '122',
        'presion_diastolica': '78',
        'frecuencia_cardiaca': '74',
        'observaciones': 'Control estable, sin síntomas de alarma.',
      },
      {
        'patient': 'Paciente demo',
        'fecha': '17/04/2026',
        'presion_sistolica': '128',
        'presion_diastolica': '82',
        'frecuencia_cardiaca': '76',
        'observaciones': 'Presión levemente elevada, reforzar adherencia.',
      },
      {
        'patient': 'Paciente demo',
        'fecha': '10/04/2026',
        'presion_sistolica': '118',
        'presion_diastolica': '76',
        'frecuencia_cardiaca': '72',
        'observaciones': 'Control estable posterior a toma de medicamento.',
      },
    ];
  }

  static DateTime? leerFechaRegistro(Map<String, String> registro) {
    final String? fecha =
        _leerTexto(registro['fecha_original']) ?? _leerTexto(registro['fecha']);

    if (fecha == null) {
      return null;
    }

    return _parsearFechaFlexible(fecha);
  }

  static Map<String, String> _mapearRegistro(Map<String, dynamic> registro) {
    final dynamic patientData = registro['patient'];
    final dynamic registradoPorData = registro['registrado_por'];

    final String patient = _leerNombrePaciente(registro, patientData);
    final String? patientId = _leerPatientId(registro, patientData);

    final String? registradoPor = registradoPorData is Map<String, dynamic>
        ? _leerTexto(registradoPorData['username']) ??
              _leerTexto(registradoPorData['name']) ??
              _leerTexto(registradoPorData['id'])
        : _leerTexto(registradoPorData);
    final String fechaOriginal =
        _leerTexto(registro['fecha_registro']) ??
        _leerTexto(registro['fecha']) ??
        _leerTexto(registro['date']) ??
        _leerTexto(registro['created_at']) ??
        'No disponible';

    final Map<String, String> registroParseado = {
      'patient': patient,
      'fecha': _formatearFechaRegistro(fechaOriginal),
      'fecha_original': fechaOriginal,
      'presion_sistolica':
          registro['presion_sistolica']?.toString() ??
          registro['systolic_pressure']?.toString() ??
          'No disponible',
      'presion_diastolica':
          registro['presion_diastolica']?.toString() ??
          registro['diastolic_pressure']?.toString() ??
          'No disponible',
      'frecuencia_cardiaca':
          registro['frecuencia_cardiaca']?.toString() ??
          registro['heart_rate']?.toString() ??
          registro['pulse']?.toString() ??
          'No informado',
      'glucosa':
          registro['glucosa']?.toString() ??
          registro['glucose']?.toString() ??
          'No informado',
      'observaciones':
          registro['observaciones']?.toString() ??
          registro['notes']?.toString() ??
          'Sin observaciones',
    };

    if (patientId != null) {
      registroParseado['patient_id'] = patientId;
    }

    if (registradoPor != null) {
      registroParseado['registrado_por'] = registradoPor;
    }

    return registroParseado;
  }

  static int _compararRegistrosPorFechaDescendente(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final DateTime? fechaA = _leerFechaCruda(a);
    final DateTime? fechaB = _leerFechaCruda(b);

    if (fechaA == null && fechaB == null) {
      return 0;
    }

    if (fechaA == null) {
      return 1;
    }

    if (fechaB == null) {
      return -1;
    }

    return fechaB.compareTo(fechaA);
  }

  static DateTime? _leerFechaCruda(Map<String, dynamic> registro) {
    final String? fecha =
        _leerTexto(registro['fecha_registro']) ??
        _leerTexto(registro['fecha']) ??
        _leerTexto(registro['date']) ??
        _leerTexto(registro['created_at']);

    if (fecha == null) {
      return null;
    }

    return _parsearFechaFlexible(fecha);
  }

  static DateTime? _parsearFechaFlexible(String fechaOriginal) {
    final String fechaLimpia = fechaOriginal.trim();

    try {
      return DateTime.parse(fechaLimpia).toLocal();
    } catch (_) {
      final String fechaSinHora = fechaLimpia.split(RegExp(r'\s+')).first;
      final String separador = fechaSinHora.contains('/') ? '/' : '-';
      final List<String> partes = fechaSinHora.split(separador);

      if (partes.length < 3) {
        return null;
      }

      final int? primeraParte = int.tryParse(partes[0]);
      final int? segundaParte = int.tryParse(partes[1]);
      final int? terceraParte = int.tryParse(partes[2]);

      if (primeraParte == null ||
          segundaParte == null ||
          terceraParte == null) {
        return null;
      }

      if (partes[0].length == 4) {
        return DateTime(primeraParte, segundaParte, terceraParte);
      }

      return DateTime(terceraParte, segundaParte, primeraParte);
    }
  }

  static String _formatearFechaRegistro(String fechaOriginal) {
    final DateTime? fechaLocal = _parsearFechaFlexible(fechaOriginal);

    if (fechaLocal == null) {
      return fechaOriginal;
    }

    final String dia = _dosDigitos(fechaLocal.day);
    final String mes = _dosDigitos(fechaLocal.month);

    if (!fechaOriginal.contains(':')) {
      return '$dia-$mes-${fechaLocal.year}';
    }

    final String hora = _dosDigitos(fechaLocal.hour);
    final String minuto = _dosDigitos(fechaLocal.minute);

    return '$dia-$mes-${fechaLocal.year} $hora:$minuto';
  }

  static String _dosDigitos(int valor) {
    return valor.toString().padLeft(2, '0');
  }

  static String _leerNombrePaciente(
    Map<String, dynamic> registro,
    dynamic patientData,
  ) {
    final String? nombreDesdeRegistro =
        _leerTexto(registro['patient_name']) ??
        _leerTexto(registro['patientName']) ??
        _leerTexto(registro['nombre_paciente']) ??
        _leerTexto(registro['patient_username']);

    if (nombreDesdeRegistro != null) {
      return _limpiarNombrePaciente(nombreDesdeRegistro);
    }

    if (patientData is Map<String, dynamic>) {
      final String? nombreDesdePaciente =
          _leerTexto(patientData['full_name']) ??
          _leerTexto(patientData['nombre_completo']) ??
          _leerTexto(patientData['username']) ??
          _leerTexto(patientData['name']) ??
          _leerTexto(patientData['nombre']);

      if (nombreDesdePaciente != null) {
        return _limpiarNombrePaciente(nombreDesdePaciente);
      }

      final String? idPaciente = _leerTexto(patientData['id']);
      return idPaciente == null
          ? 'No disponible'
          : _limpiarNombrePaciente(idPaciente);
    }

    final String? textoPaciente = _leerTexto(patientData);
    return textoPaciente == null
        ? 'No disponible'
        : _limpiarNombrePaciente(textoPaciente);
  }

  static String? _leerPatientId(
    Map<String, dynamic> registro,
    dynamic patientData,
  ) {
    final String? idDesdeRegistro =
        _leerTexto(registro['patient_id']) ??
        _leerTexto(registro['patientId']) ??
        _leerTexto(registro['paciente_id']);

    if (_pareceId(idDesdeRegistro)) {
      return idDesdeRegistro;
    }

    if (patientData is Map<String, dynamic>) {
      final String? idDesdePaciente =
          _leerTexto(patientData['id']) ??
          _leerTexto(patientData['patient_id']) ??
          _leerTexto(patientData['pk']);

      return _pareceId(idDesdePaciente) ? idDesdePaciente : null;
    }

    final String? idDesdePatient = _leerTexto(patientData);
    return _pareceId(idDesdePatient) ? idDesdePatient : null;
  }

  static String _limpiarNombrePaciente(String valor) {
    final String sinPrefijo = valor.replaceFirst(
      RegExp(r'^Paciente:\s*', caseSensitive: false),
      '',
    );
    final String limpio = sinPrefijo.trim();
    return limpio.isEmpty ? 'No disponible' : limpio;
  }

  static bool _pareceId(String? valor) {
    if (valor == null) {
      return false;
    }

    return int.tryParse(valor) != null;
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }
}
