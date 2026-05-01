import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_constants.dart';
import '../session_helper.dart';

class PacientesCuidadorService {
  const PacientesCuidadorService();

  Future<List<Map<String, String>>> cargarPacientesACargo() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return [];
      }

      final response = await http.get(
        Uri.parse(apiCaregiverPatientsUrl),
        headers: headers,
      );

      debugPrint('GET pacientes cuidador: estado HTTP ${response.statusCode}');
      debugPrint('GET pacientes cuidador: respuesta ${response.body}');

      if (response.statusCode != 200) {
        return [];
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items = _extraerItems(data);

      if (items.isEmpty) {
        debugPrint('GET pacientes cuidador: lista parseada []');
        return [];
      }

      final List<Map<String, String>> pacientes = items
          .whereType<Map<String, dynamic>>()
          .map(_mapearPaciente)
          .toList();

      debugPrint('GET pacientes cuidador: lista parseada $pacientes');
      return pacientes;
    } catch (error) {
      debugPrint('GET pacientes cuidador: error $error');
      return [];
    }
  }

  List<Map<String, String>> obtenerPacientesDemo() {
    return const [
      {
        'patient': 'María González',
        'parentesco': 'Madre',
        'es_principal': 'Sí',
        'edad': '68 años',
        'diagnostico': 'Hipertensión arterial',
        'ultimo_control': '22/04/2026',
        'estado': 'Control estable',
      },
      {
        'patient': 'Juan Pérez',
        'parentesco': 'Padre',
        'es_principal': 'Sí',
        'edad': '72 años',
        'diagnostico': 'Diabetes mellitus tipo 2',
        'ultimo_control': '18/04/2026',
        'estado': 'Requiere seguimiento',
      },
    ];
  }

  static List<dynamic> _extraerItems(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is! Map<String, dynamic>) {
      return [];
    }

    const List<String> clavesLista = [
      'results',
      'patients',
      'pacientes',
      'caregiver_patients',
      'caregiverPatients',
      'data',
      'items',
      'objects',
    ];

    for (final clave in clavesLista) {
      final dynamic value = data[clave];

      if (value is List) {
        return value;
      }
    }

    if (_parecePacienteCuidador(data)) {
      return [data];
    }

    return [];
  }

  static bool _parecePacienteCuidador(Map<String, dynamic> data) {
    return data.containsKey('patient') ||
        data.containsKey('patient_id') ||
        data.containsKey('paciente') ||
        data.containsKey('paciente_id') ||
        data.containsKey('patient_name') ||
        data.containsKey('nombre_paciente');
  }

  static Map<String, String> _mapearPaciente(Map<String, dynamic> paciente) {
    final dynamic patientData =
        paciente['patient'] ?? paciente['paciente'] ?? paciente['patient_data'];
    final String? patientId = _leerPatientId(paciente, patientData);
    final String patient = _leerNombrePaciente(
      paciente,
      patientData,
      patientId,
    );
    final String patientLimpio = patient.replaceFirst(
      RegExp(r'^Paciente:\s*'),
      '',
    );

    final String parentesco =
        _leerTexto(paciente['parentesco']) ??
        _leerTexto(paciente['relationship']) ??
        _leerTexto(paciente['relation']) ??
        'No disponible';

    final String esPrincipal =
        (paciente['es_principal'] == true || paciente['is_primary'] == true)
        ? 'Sí'
        : 'No';

    final Map<String, String> pacienteParseado = {
      'patient': patientLimpio,
      'parentesco': parentesco,
      'es_principal': esPrincipal,
      'edad':
          paciente['edad']?.toString() ??
          paciente['age']?.toString() ??
          'No disponible',
      'diagnostico':
          paciente['diagnostico']?.toString() ??
          paciente['diagnosis']?.toString() ??
          'No disponible',
      'ultimo_control':
          paciente['ultimo_control']?.toString() ??
          paciente['last_checkup']?.toString() ??
          'No disponible',
      'estado':
          paciente['estado']?.toString() ??
          paciente['status']?.toString() ??
          'No disponible',
    };

    if (patientId != null) {
      pacienteParseado['patient_id'] = patientId;
    }

    return pacienteParseado;
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  static String? _leerPatientId(
    Map<String, dynamic> paciente,
    dynamic patientData,
  ) {
    if (patientData is Map<String, dynamic>) {
      return _leerTexto(patientData['id']) ??
          _leerTexto(patientData['patient_id']) ??
          _leerTexto(patientData['pk']);
    }

    return _leerTexto(paciente['patient_id']) ??
        _leerTexto(paciente['patientId']) ??
        _leerTexto(paciente['paciente_id']) ??
        _leerTexto(paciente['pacienteId']) ??
        _leerTexto(paciente['patient']) ??
        _leerTexto(paciente['paciente']);
  }

  static String _leerNombrePaciente(
    Map<String, dynamic> paciente,
    dynamic patientData,
    String? patientId,
  ) {
    if (patientData is Map<String, dynamic>) {
      final String? nombrePaciente =
          _leerTexto(patientData['nombre']) ??
          _leerTexto(patientData['name']) ??
          _leerTexto(patientData['full_name']) ??
          _leerTexto(patientData['username']);

      if (nombrePaciente != null) {
        return nombrePaciente;
      }
    }

    final String? nombreTopLevel =
        _leerTexto(paciente['patient_name']) ??
        _leerTexto(paciente['nombre_paciente']) ??
        _leerTexto(paciente['paciente_nombre']) ??
        _leerTexto(paciente['patient_full_name']) ??
        _leerTexto(paciente['nombre']) ??
        _leerTexto(paciente['name']) ??
        _leerTexto(paciente['username']);

    if (nombreTopLevel != null) {
      return nombreTopLevel;
    }

    if (patientData is String && patientData.trim().isNotEmpty) {
      return patientData;
    }

    if (patientId != null) {
      return 'Paciente $patientId';
    }

    return 'No disponible';
  }
}
