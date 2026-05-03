import 'dart:convert';

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
    this.tomado = false,
    this.tomadoEn,
  });

  final String? id;
  final String? patient;
  final String? patientId;
  final String nombreMedicamento;
  final String dosis;
  final String hora;
  final String frecuencia;
  final bool activo;
  final bool tomado;
  final String? tomadoEn;
}

class MedicationRemindersResult {
  const MedicationRemindersResult({required this.recordatorios});

  final List<MedicationReminder> recordatorios;
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
    return crearRecordatorio(
      nombreMedicamento: nombre,
      dosis: dosis,
      hora: hora,
      frecuencia: frecuencia,
      patientId: patientId,
    );
  }

  Future<void> crearRecordatorio({
    required String nombreMedicamento,
    required String dosis,
    required String hora,
    required String frecuencia,
    int? patientId,
  }) async {
    final Map<String, String> headers = await SessionHelper.getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw const SessionExpiredException();
    }

    final Map<String, dynamic> body = {
      'nombre_medicamento': nombreMedicamento,
      'dosis': dosis,
      'hora': hora,
      'frecuencia': frecuencia,
    };

    if (patientId != null) {
      body['patient'] = patientId;
    }

    try {
      final response = await SessionHelper.authenticatedPost(
        Uri.parse(apiMedicationRemindersUrl),
        body: jsonEncode(body),
      );

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

      throw const MedicationReminderCreateException(
        'No se pudo crear el recordatorio. Intenta nuevamente.',
      );
    } on SessionExpiredException {
      rethrow;
    } on MedicationReminderCreateException {
      rethrow;
    } catch (_) {
      throw const MedicationReminderCreateException(
        'No se pudo conectar con el servidor.',
      );
    }
  }

  Future<MedicationRemindersResult> cargarRecordatorios() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        throw const SessionExpiredException();
      }

      final response = await SessionHelper.authenticatedGet(
        Uri.parse(apiMedicationRemindersUrl),
      );

      if (response.statusCode != 200) {
        return _resultadoVacio();
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items = _extraerItems(data);
      final List<MedicationReminder> recordatorios = items
          .whereType<Map<String, dynamic>>()
          .map(_mapearRecordatorio)
          .toList();

      return MedicationRemindersResult(recordatorios: recordatorios);
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return _resultadoVacio();
    }
  }

  Future<void> marcarComoTomado(int reminderId) {
    return _actualizarEstadoTomado(reminderId: reminderId, tomado: true);
  }

  Future<void> marcarComoPendiente(int reminderId) {
    return _actualizarEstadoTomado(reminderId: reminderId, tomado: false);
  }

  Future<void> _actualizarEstadoTomado({
    required int reminderId,
    required bool tomado,
  }) async {
    final Map<String, String> headers = await SessionHelper.getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw const SessionExpiredException();
    }

    try {
      final response = await SessionHelper.authenticatedPatch(
        Uri.parse('$apiMedicationRemindersUrl$reminderId/'),
        body: jsonEncode({'tomado': tomado}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      if (response.statusCode == 400) {
        throw MedicationReminderUpdateException(
          _leerMensajeError(response.body) ??
              'No se pudo actualizar el recordatorio.',
        );
      }

      throw const MedicationReminderUpdateException(
        'No se pudo actualizar el recordatorio. Intenta nuevamente.',
      );
    } on SessionExpiredException {
      rethrow;
    } on MedicationReminderUpdateException {
      rethrow;
    } catch (_) {
      throw const MedicationReminderUpdateException(
        'No se pudo conectar con el servidor.',
      );
    }
  }

  MedicationRemindersResult _resultadoVacio() {
    return const MedicationRemindersResult(recordatorios: []);
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
      tomado: _leerBoolOpcional(
        recordatorio['tomado'] ?? recordatorio['taken'],
      ),
      tomadoEn:
          _leerTexto(recordatorio['tomado_en']) ??
          _leerTexto(recordatorio['taken_at']),
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

  static bool _leerBoolOpcional(dynamic valor) {
    if (valor is bool) {
      return valor;
    }

    final String texto = valor?.toString().trim().toLowerCase() ?? '';
    if (texto.isEmpty || texto == 'null') {
      return false;
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

class MedicationReminderUpdateException implements Exception {
  const MedicationReminderUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
