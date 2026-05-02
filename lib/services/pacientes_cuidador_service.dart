import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_constants.dart';
import '../session_helper.dart';

class PacientesCuidadorService {
  const PacientesCuidadorService();

  static const String _pacientesOfflineKey = 'pacientes_cuidador_offline';

  Future<List<Map<String, String>>> cargarPacientesACargo() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return _cargarPacientesLocales();
      }

      final response = await SessionHelper.authenticatedGet(
        Uri.parse(apiCaregiverPatientsUrl),
      );

      if (response.statusCode != 200) {
        return _cargarPacientesLocales();
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items = _extraerItems(data);

      final List<Map<String, String>> pacientes = _deduplicarPacientes(
        items
            .whereType<Map<String, dynamic>>()
            .map(_mapearPaciente)
            .where((paciente) => !_esPacienteDemo(paciente))
            .toList(),
      );

      await _guardarPacientesLocales(pacientes);
      return pacientes;
    } catch (_) {
      return _cargarPacientesLocales();
    }
  }

  static Future<void> _guardarPacientesLocales(
    List<Map<String, String>> pacientes,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, String>> pacientesUnicos = {};

      for (final Map<String, String> paciente in pacientes) {
        final String? id =
            paciente['patient_id'] ??
            paciente['patientId'] ??
            paciente['paciente_id'] ??
            paciente['id'];

        if (id == null || id.isEmpty) {
          continue;
        }

        pacientesUnicos[id] = paciente;
      }

      await prefs.setString(
        _pacientesOfflineKey,
        jsonEncode(pacientesUnicos.values.toList()),
      );
    } catch (_) {
      // La cache local no debe romper la carga online.
    }
  }

  static Future<List<Map<String, String>>> _cargarPacientesLocales() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? pacientesJson = prefs.getString(_pacientesOfflineKey);

      if (pacientesJson == null || pacientesJson.isEmpty) {
        return [];
      }

      final dynamic data = jsonDecode(pacientesJson);
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            ),
          )
          .cast<Map<String, String>>()
          .where((paciente) => !_esPacienteDemo(paciente))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, String>>> cargarPacientesLocales() {
    return _cargarPacientesLocales();
  }

  static List<Map<String, String>> _deduplicarPacientes(
    List<Map<String, String>> pacientes,
  ) {
    final Map<String, Map<String, String>> pacientesPorId = {};
    final List<Map<String, String>> pacientesSinId = [];

    for (final Map<String, String> paciente in pacientes) {
      final String? id =
          paciente['patient_id'] ??
          paciente['patientId'] ??
          paciente['paciente_id'] ??
          paciente['id'];

      if (id == null || id.isEmpty) {
        pacientesSinId.add(paciente);
        continue;
      }

      pacientesPorId[id] = paciente;
    }

    return [...pacientesPorId.values, ...pacientesSinId];
  }

  static bool _esPacienteDemo(Map<String, String> paciente) {
    final String? rawPatientId =
        paciente['patient_id'] ??
        paciente['patientId'] ??
        paciente['paciente_id'] ??
        paciente['id'];
    final int? patientId = int.tryParse(rawPatientId ?? '');
    return patientId == 101 || patientId == 102;
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
    final String patientId = _extraerPatientIdReal(paciente);
    final String patient = _leerNombrePaciente(
      paciente,
      patientData,
      patientId.isEmpty ? null : patientId,
    );
    final String patientLimpio = patient.replaceFirst(
      RegExp(r'^Paciente:\s*'),
      '',
    );
    final String? relationId = _leerTexto(paciente['id']);
    final String? userId = _leerUserId(paciente, patientData);
    final String? nombre =
        _leerTexto(paciente['nombre']) ??
        _leerTexto(paciente['patient_name']) ??
        _leerTexto(paciente['nombre_paciente']) ??
        _leerTexto(patientData is Map ? patientData['nombre'] : null) ??
        (patientLimpio.isEmpty ? null : patientLimpio);
    final String? name =
        _leerTexto(paciente['name']) ??
        _leerTexto(patientData is Map ? patientData['name'] : null) ??
        nombre;
    final String? username =
        _leerTexto(paciente['username']) ??
        _leerTexto(patientData is Map ? patientData['username'] : null) ??
        _leerUsernameDesdeUser(patientData);

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
      if (patientId.isNotEmpty) 'id': patientId,
      if (patientId.isNotEmpty) 'patient_id': patientId,
      if (patientId.isNotEmpty) 'patientId': patientId,
      if (patientId.isNotEmpty) 'paciente_id': patientId,
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

    if (relationId != null) {
      pacienteParseado['caregiver_patient_id'] = relationId;
    }

    if (userId != null) {
      pacienteParseado['user_id'] = userId;
    }

    if (nombre != null) {
      pacienteParseado['nombre'] = nombre;
    }

    if (name != null) {
      pacienteParseado['name'] = name;
    }

    if (username != null) {
      pacienteParseado['username'] = username;
    }

    return pacienteParseado;
  }

  static String _extraerPatientIdReal(Map<String, dynamic> item) {
    final dynamic patient =
        item['patient'] ?? item['paciente'] ?? item['patient_data'];

    if (patient is Map) {
      final dynamic nestedId =
          patient['id'] ??
          patient['patient_id'] ??
          patient['patientId'] ??
          patient['paciente_id'] ??
          patient['pacienteId'] ??
          patient['pk'];

      if (nestedId != null && nestedId.toString().trim().isNotEmpty) {
        return nestedId.toString();
      }
    }

    final dynamic directId =
        item['patient_id'] ??
        item['patientId'] ??
        item['paciente_id'] ??
        item['pacienteId'];

    if (directId != null && directId.toString().trim().isNotEmpty) {
      return directId.toString();
    }

    return item['id']?.toString() ?? '';
  }

  static String? _leerUserId(
    Map<String, dynamic> paciente,
    dynamic patientData,
  ) {
    if (patientData is Map) {
      final dynamic user = patientData['user'];
      if (user is Map) {
        final String? idDesdeUser =
            _leerTexto(user['id']) ??
            _leerTexto(user['user_id']) ??
            _leerTexto(user['pk']);
        if (idDesdeUser != null) {
          return idDesdeUser;
        }
      }

      final String? idDesdePaciente =
          _leerTexto(patientData['user_id']) ??
          _leerTexto(patientData['userId']);
      if (idDesdePaciente != null) {
        return idDesdePaciente;
      }
    }

    final dynamic user = paciente['user'];
    if (user is Map) {
      return _leerTexto(user['id']) ??
          _leerTexto(user['user_id']) ??
          _leerTexto(user['pk']);
    }

    return _leerTexto(paciente['user_id']) ?? _leerTexto(paciente['userId']);
  }

  static String? _leerUsernameDesdeUser(dynamic patientData) {
    if (patientData is! Map) {
      return null;
    }

    final dynamic user = patientData['user'];
    if (user is! Map) {
      return null;
    }

    return _leerTexto(user['username']) ??
        _leerTexto(user['name']) ??
        _leerTexto(user['full_name']);
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
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
