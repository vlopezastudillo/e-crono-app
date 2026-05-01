import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_constants.dart';
import '../session_helper.dart';

class MedicationReminder {
  const MedicationReminder({
    required this.nombreMedicamento,
    required this.dosis,
    required this.hora,
    required this.frecuencia,
    required this.activo,
    this.id,
    this.patient,
    this.patientId,
    this.isDemo = false,
  });

  final String? id;
  final String? patient;
  final String? patientId;
  final String nombreMedicamento;
  final String dosis;
  final String hora;
  final String frecuencia;
  final bool activo;
  final bool isDemo;
}

class MedicationRemindersResult {
  const MedicationRemindersResult({
    required this.recordatorios,
    required this.usandoDemo,
  });

  final List<MedicationReminder> recordatorios;
  final bool usandoDemo;
}

class MedicationRemindersService {
  const MedicationRemindersService();

  Future<void> createMedicationReminder({
    required int patientId,
    required String nombre,
    required String dosis,
    required String hora,
    required String frecuencia,
  }) async {
    final Map<String, String> headers = await SessionHelper.getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw const MedicationReminderCreateException('Sesión inválida.');
    }

    final Map<String, dynamic> body = {
      'patient': patientId,
      'nombre_medicamento': nombre,
      'dosis': dosis,
      'hora': hora,
      'frecuencia': frecuencia,
      'activo': true,
    };

    try {
      final response = await http.post(
        Uri.parse(apiMedicationRemindersUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint(
        'POST recordatorio medicamento: estado HTTP ${response.statusCode}',
      );
      debugPrint('POST recordatorio medicamento: respuesta ${response.body}');

      if (response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 400) {
        throw MedicationReminderCreateException(
          _leerMensajeError(response.body) ??
              'Revisa los datos del recordatorio.',
        );
      }

      if (response.statusCode == 403) {
        throw const MedicationReminderCreateException(
          'No puedes crear recordatorios para un paciente no vinculado.',
        );
      }

      if (response.statusCode == 401) {
        throw const MedicationReminderCreateException('Sesión inválida.');
      }

      throw const MedicationReminderCreateException(
        'No se pudo crear el recordatorio. Intenta nuevamente.',
      );
    } on MedicationReminderCreateException {
      rethrow;
    } catch (error) {
      debugPrint('POST recordatorio medicamento: error $error');
      throw const MedicationReminderCreateException(
        'No se pudo conectar con el servidor.',
      );
    }
  }

  Future<MedicationRemindersResult> cargarRecordatorios() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return _resultadoDemo();
      }

      final response = await http.get(
        Uri.parse(apiMedicationRemindersUrl),
        headers: headers,
      );

      debugPrint(
        'GET recordatorios medicamentos: estado HTTP ${response.statusCode}',
      );
      debugPrint('GET recordatorios medicamentos: respuesta ${response.body}');

      if (response.statusCode != 200) {
        return _resultadoDemo();
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items = _extraerItems(data);
      final List<MedicationReminder> recordatorios = items
          .whereType<Map<String, dynamic>>()
          .map(_mapearRecordatorio)
          .toList();

      return MedicationRemindersResult(
        recordatorios: recordatorios,
        usandoDemo: false,
      );
    } catch (error) {
      debugPrint('GET recordatorios medicamentos: error $error');
      return _resultadoDemo();
    }
  }

  MedicationRemindersResult _resultadoDemo() {
    return const MedicationRemindersResult(
      usandoDemo: true,
      recordatorios: [
        MedicationReminder(
          id: 'demo-1',
          nombreMedicamento: 'Enalapril',
          dosis: '10 mg',
          hora: '08:00',
          frecuencia: 'Diaria',
          activo: true,
          isDemo: true,
        ),
        MedicationReminder(
          id: 'demo-2',
          nombreMedicamento: 'Metformina',
          dosis: '850 mg',
          hora: '13:00',
          frecuencia: 'Diaria',
          activo: true,
          isDemo: true,
        ),
      ],
    );
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
      'recordatorios',
      'reminders',
      'medication_reminders',
      'data',
      'items',
    ];

    for (final clave in clavesLista) {
      final dynamic value = data[clave];

      if (value is List) {
        return value;
      }
    }

    if (data.containsKey('nombre_medicamento') ||
        data.containsKey('medication_name')) {
      return [data];
    }

    return [];
  }

  static MedicationReminder _mapearRecordatorio(
    Map<String, dynamic> recordatorio,
  ) {
    final dynamic patientData = recordatorio['patient'];

    return MedicationReminder(
      id: _leerTexto(recordatorio['id']),
      patient: _leerNombrePaciente(patientData),
      patientId:
          _leerTexto(recordatorio['patient_id']) ??
          _leerTexto(recordatorio['patientId']) ??
          _leerPatientId(patientData),
      nombreMedicamento:
          _leerTexto(recordatorio['nombre_medicamento']) ??
          _leerTexto(recordatorio['medication_name']) ??
          _leerTexto(recordatorio['name']) ??
          'Medicamento sin nombre',
      dosis:
          _leerTexto(recordatorio['dosis']) ??
          _leerTexto(recordatorio['dose']) ??
          'Dosis no informada',
      hora:
          _leerTexto(recordatorio['hora']) ??
          _leerTexto(recordatorio['time']) ??
          'Hora no informada',
      frecuencia:
          _leerTexto(recordatorio['frecuencia']) ??
          _leerTexto(recordatorio['frequency']) ??
          'Frecuencia no informada',
      activo: _leerBool(recordatorio['activo'] ?? recordatorio['active']),
    );
  }

  static String? _leerNombrePaciente(dynamic patientData) {
    if (patientData is Map<String, dynamic>) {
      return _leerTexto(patientData['nombre']) ??
          _leerTexto(patientData['name']) ??
          _leerTexto(patientData['full_name']) ??
          _leerTexto(patientData['username']) ??
          _leerTexto(patientData['id']);
    }

    return _leerTexto(patientData);
  }

  static String? _leerPatientId(dynamic patientData) {
    if (patientData is Map<String, dynamic>) {
      return _leerTexto(patientData['id']) ??
          _leerTexto(patientData['patient_id']) ??
          _leerTexto(patientData['pk']);
    }

    return _leerTexto(patientData);
  }

  static bool _leerBool(dynamic valor) {
    if (valor is bool) {
      return valor;
    }

    final String texto = valor?.toString().trim().toLowerCase() ?? '';

    if (texto.isEmpty) {
      return true;
    }

    return texto == 'true' || texto == '1' || texto == 'sí' || texto == 'si';
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  static String? _leerMensajeError(String body) {
    try {
      final dynamic data = jsonDecode(body);

      if (data is Map<String, dynamic>) {
        for (final clave in [
          'detail',
          'error',
          'message',
          'non_field_errors',
        ]) {
          final String? mensaje = _leerTexto(data[clave]);
          if (mensaje != null) {
            return mensaje;
          }
        }

        for (final value in data.values) {
          if (value is List && value.isNotEmpty) {
            final String? mensaje = _leerTexto(value.first);
            if (mensaje != null) {
              return mensaje;
            }
          }

          final String? mensaje = _leerTexto(value);
          if (mensaje != null) {
            return mensaje;
          }
        }
      }

      if (data is List && data.isNotEmpty) {
        return _leerTexto(data.first);
      }
    } catch (_) {
      return _leerTexto(body);
    }

    return null;
  }
}

class MedicationReminderCreateException implements Exception {
  const MedicationReminderCreateException(this.message);

  final String message;

  @override
  String toString() => message;
}
