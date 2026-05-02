import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_constants.dart';
import '../services/offline_vital_signs_service.dart';
import '../services/pacientes_cuidador_service.dart';
import '../session_helper.dart';

class RegistrosClinicosService {
  const RegistrosClinicosService();

  static const String _registrosVinculadosOfflineKey =
      'registros_clinicos_vinculados_offline';

  Future<List<Map<String, String>>> cargarMisRegistros() async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return _cargarRegistrosLocales();
      }

      final response = await SessionHelper.authenticatedGet(
        Uri.parse(apiVitalSignRecordsUrl),
      );

      if (response.statusCode != 200) {
        return _cargarRegistrosLocales();
      }

      final dynamic data = jsonDecode(response.body);
      final List<dynamic> items;

      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic> && data['results'] is List) {
        items = data['results'] as List<dynamic>;
      } else {
        return _cargarRegistrosLocales();
      }

      final List<Map<String, dynamic>> registros = items
          .whereType<Map<String, dynamic>>()
          .toList();

      registros.sort(_compararRegistrosPorFechaDescendente);

      final List<Map<String, String>> registrosMapeados = _deduplicarRegistros(
        registros
            .map(_mapearRegistro)
            .where((registro) => !_esRegistroDemo(registro))
            .toList(),
      );

      await _guardarRegistrosLocales(registrosMapeados);
      return registrosMapeados;
    } catch (_) {
      return _cargarRegistrosLocales();
    }
  }

  static Future<List<Map<String, dynamic>>>
  obtenerRegistrosConsolidados() async {
    try {
      final RegistrosClinicosService service = RegistrosClinicosService();
      final List<Map<String, String>> registrosBackendOCache = await service
          .cargarMisRegistros();
      final List<Map<String, dynamic>> registrosPendientes =
          await OfflineVitalSignsService.obtenerRegistrosPendientes();
      final List<Map<String, String>> pacientesLocales =
          await PacientesCuidadorService.cargarPacientesLocales();
      final Map<String, Map<String, String>> pacientesPorId = {};
      final Map<String, Map<String, String>> pacientesPorNombre = {};

      _indexarPacientesLocales(
        pacientesLocales,
        pacientesPorId,
        pacientesPorNombre,
      );

      final List<Map<String, String>> registrosCompatibles =
          [
                ...registrosPendientes.map(_mapearRegistroPendiente),
                ...registrosBackendOCache,
              ]
              .map(_normalizarRegistroConsolidado)
              .map(
                (registro) => _normalizarRegistroConPacienteLocal(
                  Map<String, dynamic>.from(registro),
                  pacientesPorId,
                  pacientesPorNombre,
                ),
              )
              .map(_convertirRegistroAStringMap)
              .where((registro) => !_esRegistroDemo(registro))
              .toList();

      final List<Map<String, String>> registrosOrdenados =
          _ordenarRegistrosPorFechaDescendente(
            _deduplicarRegistros(registrosCompatibles),
          );

      return registrosOrdenados
          .map((registro) => Map<String, dynamic>.from(registro))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _guardarRegistrosLocales(
    List<Map<String, String>> registros,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _registrosVinculadosOfflineKey,
        jsonEncode(_deduplicarRegistros(registros)),
      );
    } catch (_) {
      // La cache no debe romper la carga online.
    }
  }

  static Future<List<Map<String, String>>> _cargarRegistrosLocales() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_registrosVinculadosOfflineKey);

      if (raw == null || raw.isEmpty) {
        return [];
      }

      final dynamic data = jsonDecode(raw);
      if (data is! List) {
        return [];
      }

      final List<Map<String, String>> registros = data
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            ),
          )
          .cast<Map<String, String>>()
          .map(_normalizarRegistroConsolidado)
          .where((registro) => !_esRegistroDemo(registro))
          .toList();

      return _deduplicarRegistros(registros);
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, String>> _deduplicarRegistros(
    List<Map<String, String>> registros,
  ) {
    final Map<String, Map<String, String>> registrosUnicos = {};

    for (final Map<String, String> registro in registros) {
      final String clave = _claveRegistro(registro);
      registrosUnicos[clave] = registro;
    }

    return registrosUnicos.values.toList();
  }

  static List<Map<String, String>> _ordenarRegistrosPorFechaDescendente(
    List<Map<String, String>> registros,
  ) {
    final List<Map<String, String>> registrosOrdenados = [...registros];

    registrosOrdenados.sort((a, b) {
      final DateTime? fechaA = leerFechaRegistro(a);
      final DateTime? fechaB = leerFechaRegistro(b);

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
    });

    return registrosOrdenados;
  }

  static String _claveRegistro(Map<String, String> registro) {
    final String? id =
        _leerTexto(registro['id']) ??
        _leerTexto(registro['registro_id']) ??
        _leerTexto(registro['pk']);

    if (id != null) {
      return 'id:$id';
    }

    return [
      _leerTexto(registro['patient_id_normalizado']) ??
          _leerTexto(registro['patient_id']) ??
          _leerTexto(registro['patientId']) ??
          _leerTexto(registro['paciente_id']) ??
          _leerTexto(registro['patient']) ??
          '',
      _leerTexto(registro['fecha_original']) ??
          _leerTexto(registro['fecha']) ??
          '',
      _leerTexto(registro['presion_sistolica']) ?? '',
      _leerTexto(registro['presion_diastolica']) ?? '',
      _leerTexto(registro['glucosa']) ?? '',
      _leerTexto(registro['frecuencia_cardiaca']) ?? '',
    ].join('|');
  }

  static Map<String, String> _normalizarRegistroConsolidado(
    Map<String, String> registro,
  ) {
    final String patientId = _extraerPatientIdRegistro(registro);

    if (patientId.isEmpty) {
      return registro;
    }

    return {
      ...registro,
      'patient_id_normalizado': patientId,
      if (_leerTexto(registro['patient_id']) == null) 'patient_id': patientId,
      if (_leerTexto(registro['paciente_id']) == null) 'paciente_id': patientId,
    };
  }

  static void _indexarPacientesLocales(
    List<Map<String, String>> pacientes,
    Map<String, Map<String, String>> pacientesPorId,
    Map<String, Map<String, String>> pacientesPorNombre,
  ) {
    for (final Map<String, String> paciente in pacientes) {
      final List<String?> ids = [
        paciente['id'],
        paciente['patient_id'],
        paciente['patientId'],
        paciente['paciente_id'],
      ];

      for (final String? id in ids) {
        final String idLimpio = id?.trim() ?? '';
        if (idLimpio.isNotEmpty) {
          pacientesPorId[idLimpio] = paciente;
        }
      }

      final List<String?> nombres = [
        paciente['nombre'],
        paciente['name'],
        paciente['username'],
        paciente['full_name'],
        paciente['patient'],
      ];

      for (final String? nombre in nombres) {
        final String nombreNormalizado = _normalizarNombre(nombre);
        if (nombreNormalizado.isNotEmpty) {
          pacientesPorNombre[nombreNormalizado] = paciente;
        }
      }
    }
  }

  static Map<String, dynamic> _normalizarRegistroConPacienteLocal(
    Map<String, dynamic> registro,
    Map<String, Map<String, String>> pacientesPorId,
    Map<String, Map<String, String>> pacientesPorNombre,
  ) {
    final Map<String, dynamic> registroNormalizado = {...registro};
    final String patientIdExtraido = _extraerPatientIdRegistro(registro);
    final Map<String, String>? pacientePorId = patientIdExtraido.isEmpty
        ? null
        : pacientesPorId[patientIdExtraido];

    if (pacientePorId != null) {
      return _aplicarPacienteLocalARegistro(registroNormalizado, pacientePorId);
    }

    for (final String nombre in _extraerNombresRegistro(registro)) {
      final Map<String, String>? pacientePorNombre =
          pacientesPorNombre[_normalizarNombre(nombre)];

      if (pacientePorNombre != null) {
        return _aplicarPacienteLocalARegistro(
          registroNormalizado,
          pacientePorNombre,
        );
      }
    }

    if (patientIdExtraido.isNotEmpty) {
      registroNormalizado['patient_id_normalizado'] = patientIdExtraido;
    }

    return registroNormalizado;
  }

  static Map<String, dynamic> _aplicarPacienteLocalARegistro(
    Map<String, dynamic> registro,
    Map<String, String> paciente,
  ) {
    final String? patientId =
        _leerTexto(paciente['patient_id']) ??
        _leerTexto(paciente['id']) ??
        _leerTexto(paciente['patientId']) ??
        _leerTexto(paciente['paciente_id']);
    final String? patientName =
        _leerTexto(paciente['nombre']) ??
        _leerTexto(paciente['name']) ??
        _leerTexto(paciente['username']) ??
        _leerTexto(paciente['full_name']) ??
        _leerTexto(paciente['patient']);

    final Map<String, dynamic> registroNormalizado = {...registro};

    if (patientId != null) {
      registroNormalizado['patient_id_normalizado'] = patientId;
      if (_leerTexto(registro['patient_id']) == null) {
        registroNormalizado['patient_id'] = patientId;
      }
      if (_leerTexto(registro['paciente_id']) == null) {
        registroNormalizado['paciente_id'] = patientId;
      }
    }

    if (patientName != null) {
      registroNormalizado['patient_name'] = patientName;
      registroNormalizado['patient'] = patientName;
    }

    return registroNormalizado;
  }

  static List<String> _extraerNombresRegistro(Map<String, dynamic> registro) {
    final List<String> nombres = [];

    void agregar(dynamic valor) {
      final String? texto = _leerTexto(valor);
      if (texto != null) {
        nombres.add(texto);
      }
    }

    agregar(registro['patient_name']);
    agregar(registro['nombre_paciente']);
    agregar(registro['paciente_nombre']);
    agregar(registro['username']);
    agregar(registro['name']);

    final dynamic patient = registro['patient'];
    if (patient is Map) {
      agregar(patient['username']);
      agregar(patient['name']);
      agregar(patient['full_name']);
      agregar(patient['nombre']);
    } else {
      agregar(patient);
    }

    final dynamic paciente = registro['paciente'];
    if (paciente is Map) {
      agregar(paciente['username']);
      agregar(paciente['name']);
      agregar(paciente['full_name']);
      agregar(paciente['nombre']);
    } else {
      agregar(paciente);
    }

    return nombres;
  }

  static Map<String, String> _convertirRegistroAStringMap(
    Map<String, dynamic> registro,
  ) {
    return registro.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  static String _normalizarNombre(String? valor) {
    return (valor ?? '').trim().toLowerCase();
  }

  static String _extraerPatientIdRegistro(Map<String, dynamic> registro) {
    final dynamic patient = registro['patient'];
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

    final dynamic paciente = registro['paciente'];
    if (paciente is Map) {
      final dynamic nestedId =
          paciente['id'] ??
          paciente['patient_id'] ??
          paciente['patientId'] ??
          paciente['paciente_id'] ??
          paciente['pacienteId'] ??
          paciente['pk'];

      if (nestedId != null && nestedId.toString().trim().isNotEmpty) {
        return nestedId.toString();
      }
    }

    final dynamic directId =
        registro['patient_id'] ??
        registro['patientId'] ??
        registro['paciente_id'] ??
        registro['pacienteId'];

    if (directId != null && directId.toString().trim().isNotEmpty) {
      return directId.toString();
    }

    final dynamic rawPatient = registro['patient'];
    if (rawPatient != null && rawPatient is! Map) {
      return rawPatient.toString();
    }

    return '';
  }

  static bool _esRegistroDemo(Map<String, String> registro) {
    final String? rawPatientId =
        _leerTexto(registro['patient_id_normalizado']) ??
        _leerTexto(registro['patient_id']) ??
        _leerTexto(registro['patientId']) ??
        _leerTexto(registro['paciente_id']) ??
        _leerTexto(registro['patient']);
    final int? patientId = int.tryParse(
      rawPatientId?.replaceFirst(
            RegExp(r'^Paciente:\s*', caseSensitive: false),
            '',
          ) ??
          '',
    );
    return patientId == 101 || patientId == 102;
  }

  static Map<String, String> _mapearRegistroPendiente(
    Map<String, dynamic> registro,
  ) {
    final String patientIdExtraido = _extraerPatientIdRegistro(registro);
    final String patientId = patientIdExtraido.isEmpty
        ? '1'
        : patientIdExtraido;
    final String fechaOriginal =
        _leerTexto(registro['created_at_local']) ??
        _leerTexto(registro['fecha_registro']) ??
        _leerTexto(registro['fecha']) ??
        DateTime.now().toIso8601String();

    return {
      if (_leerTexto(registro['local_id']) != null)
        'local_id': _leerTexto(registro['local_id'])!,
      'patient':
          _leerTexto(registro['patient_name']) ??
          _leerTexto(registro['paciente_nombre']) ??
          _leerTexto(registro['nombre_paciente']) ??
          patientId,
      'patient_id': patientId,
      'paciente_id': patientId,
      'patient_id_normalizado': patientId,
      'fecha': _formatearFechaRegistro(fechaOriginal),
      'fecha_original': fechaOriginal,
      'presion_sistolica':
          _leerTexto(registro['presion_sistolica']) ?? 'No disponible',
      'presion_diastolica':
          _leerTexto(registro['presion_diastolica']) ?? 'No disponible',
      'frecuencia_cardiaca':
          _leerTexto(registro['frecuencia_cardiaca']) ?? 'No informado',
      'glucosa': _leerTexto(registro['glucosa']) ?? 'No informado',
      'observaciones':
          _leerTexto(registro['observaciones']) ?? 'Sin observaciones',
      'sync_status': 'pending',
      'estado_sincronizacion': 'Pendiente de sincronizar',
    };
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
    final String patientId = _extraerPatientIdRegistro(registro);

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
      if (registro['id'] != null) 'id': registro['id'].toString(),
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

    if (patientId.isNotEmpty) {
      registroParseado['patient_id'] = patientId;
      registroParseado['paciente_id'] = patientId;
      registroParseado['patient_id_normalizado'] = patientId;
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

  static String _limpiarNombrePaciente(String valor) {
    final String sinPrefijo = valor.replaceFirst(
      RegExp(r'^Paciente:\s*', caseSensitive: false),
      '',
    );
    final String limpio = sinPrefijo.trim();
    return limpio.isEmpty ? 'No disponible' : limpio;
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }
}
