import 'dart:convert';

import 'package:flutter/material.dart';

import '../api_constants.dart';
import '../route_observer.dart';
import '../services/offline_vital_signs_service.dart';
import '../services/pacientes_cuidador_service.dart';
import '../services/registros_clinicos_service.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';
import 'detalle_registro_clinico.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
const Color _clinicalBorder = Color(0xFFE5E7EB);
const Color _clinicalTextPrimary = Color(0xFF111827);
const Color _clinicalTextSecondary = Color(0xFF6B7280);
const Color _clinicalSoftBlue = Color(0xFFEFF6FF);

// Pantalla simple para listar los registros clinicos del paciente.
class PantallaMisRegistros extends StatefulWidget {
  const PantallaMisRegistros({
    super.key,
    this.patientId,
    this.patientName,
    this.registrosFiltrados,
    this.fechaFiltrada,
  });

  final int? patientId;
  final String? patientName;
  final List<Map<String, String>>? registrosFiltrados;
  final DateTime? fechaFiltrada;

  @override
  State<PantallaMisRegistros> createState() => _PantallaMisRegistrosState();
}

class _PantallaMisRegistrosState extends State<PantallaMisRegistros>
    with RouteAware {
  late Future<List<Map<String, String>>> _registrosFuture;
  String? _role;
  String? _pacienteSeleccionadoFiltro;
  RegistroClinicoSemaforo? _estadoSeleccionadoFiltro;
  DateTime? _fechaFiltro;
  bool _suscritoARuta = false;
  bool _autoSyncEjecutado = false;

  @override
  void initState() {
    super.initState();
    // Carga la lista completa salvo cuando otra pantalla ya entrega un filtro.
    _registrosFuture = _cargarRegistrosIniciales();
    _cargarRolUsuario();
    _intentarAutoSincronizacion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<void>? route = ModalRoute.of(context);
    if (!_suscritoARuta && route != null) {
      routeObserver.subscribe(this, route);
      _suscritoARuta = true;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Al volver desde otra pantalla, consulta nuevamente la API.
    _recargarRegistros();
  }

  void _recargarRegistros() {
    setState(() {
      _registrosFuture = _cargarRegistrosIniciales();
    });
  }

  Future<void> _intentarAutoSincronizacion() async {
    if (_autoSyncEjecutado) {
      return;
    }

    _autoSyncEjecutado = true;

    final List<Map<String, dynamic>> registrosPendientes =
        await OfflineVitalSignsService.obtenerRegistrosPendientes();

    if (registrosPendientes.isEmpty) {
      return;
    }

    bool huboFallas = false;
    bool intentoSincronizar = false;

    for (final Map<String, dynamic> registro in registrosPendientes) {
      if (registro['is_demo'] == 'true') {
        continue;
      }

      final String? localId = _leerTexto(registro['local_id']);
      if (localId == null) {
        huboFallas = true;
        continue;
      }

      intentoSincronizar = true;
      final bool sincronizado = await _sincronizarRegistroPendiente(registro);
      if (!sincronizado) {
        huboFallas = true;
        continue;
      }

      final bool eliminado =
          await OfflineVitalSignsService.eliminarRegistroPendiente(localId);
      if (!eliminado) {
        huboFallas = true;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _registrosFuture = _cargarRegistrosIniciales();
    });

    if (intentoSincronizar && !huboFallas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registros sincronizados automáticamente.'),
        ),
      );
    }
  }

  Future<bool> _sincronizarRegistroPendiente(
    Map<String, dynamic> registroPendiente,
  ) async {
    try {
      final Map<String, dynamic> datosRegistro =
          _prepararRegistroPendienteParaBackend(registroPendiente);

      final response = await SessionHelper.authenticatedPost(
        Uri.parse(apiVitalSignRecordsUrl),
        body: jsonEncode(datosRegistro),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _prepararRegistroPendienteParaBackend(
    Map<String, dynamic> registroPendiente,
  ) {
    final Map<String, dynamic> datosRegistro = Map<String, dynamic>.from(
      registroPendiente,
    );
    datosRegistro.remove('local_id');
    datosRegistro.remove('created_at_local');
    datosRegistro.remove('sync_status');
    datosRegistro.remove('estado_sincronizacion');
    datosRegistro.remove('is_demo');
    return datosRegistro;
  }

  Future<List<Map<String, String>>> _cargarRegistrosIniciales() async {
    final List<Map<String, String>>? registrosFiltrados =
        widget.registrosFiltrados;
    final Map<String, Map<String, String>> pacientesPorId =
        await _cargarPacientesLocalesPorId();

    if (registrosFiltrados != null) {
      final List<Map<String, String>> registrosPendientes =
          await _cargarRegistrosPendientesCompatibles(pacientesPorId);

      return _prepararRegistrosParaVista([
        ..._filtrarRegistrosPendientesParaVista(registrosPendientes),
        ...registrosFiltrados,
      ], pacientesPorId);
    }

    final List<Map<String, dynamic>> registrosConsolidados =
        await RegistrosClinicosService.obtenerRegistrosConsolidados();

    return _prepararRegistrosParaVista(
      registrosConsolidados.map(_mapearRegistroConsolidadoParaVista).toList(),
      pacientesPorId,
    );
  }

  Future<void> _cargarRolUsuario() async {
    final String? role = await SessionHelper.getRole();

    if (!mounted) {
      return;
    }

    setState(() {
      _role = role;
    });
  }

  Future<Map<String, Map<String, String>>>
  _cargarPacientesLocalesPorId() async {
    final List<Map<String, String>> pacientes =
        await PacientesCuidadorService.cargarPacientesLocales();
    final Map<String, Map<String, String>> pacientesPorId = {};

    for (final Map<String, String> paciente in pacientes) {
      _registrarPacienteEnMapa(pacientesPorId, paciente['id'], paciente);
      _registrarPacienteEnMapa(
        pacientesPorId,
        paciente['patient_id'],
        paciente,
      );
      _registrarPacienteEnMapa(pacientesPorId, paciente['patientId'], paciente);
      _registrarPacienteEnMapa(
        pacientesPorId,
        paciente['paciente_id'],
        paciente,
      );
    }

    return pacientesPorId;
  }

  void _registrarPacienteEnMapa(
    Map<String, Map<String, String>> pacientesPorId,
    String? id,
    Map<String, String> paciente,
  ) {
    final String idLimpio = id?.trim() ?? '';
    if (idLimpio.isEmpty) {
      return;
    }

    pacientesPorId[idLimpio] = paciente;
  }

  Future<List<Map<String, String>>> _cargarRegistrosPendientesCompatibles(
    Map<String, Map<String, String>> pacientesPorId,
  ) async {
    final List<Map<String, dynamic>> registrosPendientes =
        await OfflineVitalSignsService.obtenerRegistrosPendientes();
    final List<Map<String, String>> registrosCompatibles = registrosPendientes
        .map((registro) => _mapearRegistroPendiente(registro, pacientesPorId))
        .where((registro) => !_esRegistroDemo(registro))
        .toList();

    return registrosCompatibles;
  }

  List<Map<String, String>> _prepararRegistrosParaVista(
    List<Map<String, String>> registros,
    Map<String, Map<String, String>> pacientesPorId,
  ) {
    final List<Map<String, String>> registrosConNombre = registros
        .where((registro) => !_esRegistroDemo(registro))
        .map((registro) => _resolverNombrePaciente(registro, pacientesPorId))
        .toList();

    return _ordenarRegistrosPorFechaDescendente(
      _deduplicarRegistros(registrosConNombre),
    );
  }

  List<Map<String, String>> _ordenarRegistrosPorFechaDescendente(
    List<Map<String, String>> registros,
  ) {
    final List<Map<String, String>> registrosOrdenados = [...registros];

    registrosOrdenados.sort((a, b) {
      final DateTime? fechaA = RegistrosClinicosService.leerFechaRegistro(a);
      final DateTime? fechaB = RegistrosClinicosService.leerFechaRegistro(b);

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

  List<Map<String, String>> _filtrarRegistrosPendientesParaVista(
    List<Map<String, String>> registrosPendientes,
  ) {
    final DateTime? fechaFiltrada = widget.fechaFiltrada;
    final int? patientId = widget.patientId;

    return registrosPendientes.where((registro) {
      final bool coincidePaciente =
          patientId == null ||
          _registroPerteneceAlPaciente(
            registro,
            patientId.toString(),
            widget.patientName,
          );
      final DateTime? fechaRegistro =
          RegistrosClinicosService.leerFechaRegistro(registro);
      final bool coincideFecha =
          fechaFiltrada == null ||
          (fechaRegistro != null && _mismoDia(fechaRegistro, fechaFiltrada));

      return coincidePaciente && coincideFecha;
    }).toList();
  }

  Map<String, String> _mapearRegistroConsolidadoParaVista(
    Map<String, dynamic> registro,
  ) {
    final Map<String, String> registroMapeado = registro.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
    final String patientId = _extraerPatientIdRegistro(registro);

    if (patientId.isEmpty) {
      return registroMapeado;
    }

    return {
      ...registroMapeado,
      'patient_id_normalizado': patientId,
      if (_leerTexto(registroMapeado['patient_id']) == null)
        'patient_id': patientId,
      if (_leerTexto(registroMapeado['paciente_id']) == null)
        'paciente_id': patientId,
    };
  }

  Map<String, String> _mapearRegistroPendiente(
    Map<String, dynamic> registroPendiente,
    Map<String, Map<String, String>> pacientesPorId,
  ) {
    final String patientIdExtraido = _extraerPatientIdRegistro(
      registroPendiente,
    );
    final String patientId = patientIdExtraido.isEmpty
        ? '1'
        : patientIdExtraido;
    final String fechaOriginal =
        _leerTexto(registroPendiente['created_at_local']) ??
        DateTime.now().toIso8601String();
    final String? patientName = widget.patientId?.toString() == patientId
        ? widget.patientName?.trim()
        : _nombrePacienteDesdeCache(patientId, pacientesPorId);

    return {
      'local_id': _leerTexto(registroPendiente['local_id']) ?? '',
      'patient': (patientName == null || patientName.isEmpty)
          ? patientId
          : patientName,
      'patient_id': patientId,
      'paciente_id': patientId,
      'patient_id_normalizado': patientId,
      'fecha': _formatearFechaLocal(fechaOriginal),
      'fecha_original': fechaOriginal,
      'presion_sistolica':
          _leerTexto(registroPendiente['presion_sistolica']) ?? 'No disponible',
      'presion_diastolica':
          _leerTexto(registroPendiente['presion_diastolica']) ??
          'No disponible',
      'frecuencia_cardiaca':
          _leerTexto(registroPendiente['frecuencia_cardiaca']) ??
          'No informado',
      'glucosa': _leerTexto(registroPendiente['glucosa']) ?? 'No informado',
      'observaciones':
          _leerTexto(registroPendiente['observaciones']) ?? 'Sin observaciones',
      'sync_status': 'pending',
      'estado_sincronizacion': 'Pendiente de sincronizar',
    };
  }

  Map<String, String> _resolverNombrePaciente(
    Map<String, String> registro,
    Map<String, Map<String, String>> pacientesPorId,
  ) {
    final String? nombreDirecto =
        _leerTexto(registro['patient_name']) ??
        _leerTexto(registro['paciente_nombre']) ??
        _leerTexto(registro['nombre_paciente']);

    if (nombreDirecto != null) {
      return {...registro, 'patient': nombreDirecto};
    }

    final String? patientActual = _leerTexto(registro['patient']);
    final bool patientActualPareceId =
        patientActual != null &&
        int.tryParse(patientActual.replaceFirst('Paciente: ', '')) != null;

    if (patientActual != null && !patientActualPareceId) {
      return registro;
    }

    final String? patientId =
        _leerTexto(registro['patient_id_normalizado']) ??
        _leerTexto(registro['patient_id']) ??
        _leerTexto(registro['patientId']) ??
        _leerTexto(registro['paciente_id']) ??
        patientActual?.replaceFirst('Paciente: ', '');

    final String? nombreDesdeCache = _nombrePacienteDesdeCache(
      patientId,
      pacientesPorId,
    );

    if (nombreDesdeCache == null) {
      return {
        ...registro,
        'patient': 'Paciente: ${patientId ?? 'sin identificar'}',
      };
    }

    return {...registro, 'patient': nombreDesdeCache};
  }

  String? _nombrePacienteDesdeCache(
    String? patientId,
    Map<String, Map<String, String>> pacientesPorId,
  ) {
    final String idLimpio = patientId?.trim() ?? '';
    if (idLimpio.isEmpty) {
      return null;
    }

    final Map<String, String>? paciente = pacientesPorId[idLimpio];
    if (paciente == null) {
      return null;
    }

    return _leerTexto(paciente['patient']) ??
        _leerTexto(paciente['nombre']) ??
        _leerTexto(paciente['name']) ??
        _leerTexto(paciente['full_name']) ??
        _leerTexto(paciente['username']);
  }

  List<Map<String, String>> _deduplicarRegistros(
    List<Map<String, String>> registros,
  ) {
    final Map<String, Map<String, String>> registrosPorClave = {};

    for (final Map<String, String> registro in registros) {
      registrosPorClave[_claveRegistro(registro)] = registro;
    }

    return registrosPorClave.values.toList();
  }

  String _claveRegistro(Map<String, String> registro) {
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

  bool _esRegistroDemo(Map<String, String> registro) {
    final String? rawPatientId =
        _leerTexto(registro['patient_id_normalizado']) ??
        _leerTexto(registro['patient_id']) ??
        _leerTexto(registro['patientId']) ??
        _leerTexto(registro['paciente_id']) ??
        _leerTexto(registro['patient']);
    final int? patientId = int.tryParse(
      rawPatientId?.replaceFirst('Paciente: ', '') ?? '',
    );
    return patientId == 101 || patientId == 102;
  }

  String _formatearFechaLocal(String fechaOriginal) {
    try {
      final DateTime fechaLocal = DateTime.parse(fechaOriginal).toLocal();
      final String dia = fechaLocal.day.toString().padLeft(2, '0');
      final String mes = fechaLocal.month.toString().padLeft(2, '0');
      final String hora = fechaLocal.hour.toString().padLeft(2, '0');
      final String minuto = fechaLocal.minute.toString().padLeft(2, '0');

      return '$dia-$mes-${fechaLocal.year} $hora:$minuto';
    } catch (_) {
      return fechaOriginal;
    }
  }

  String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  List<Map<String, String>> _filtrarRegistrosPorPaciente(
    List<Map<String, String>> registros,
  ) {
    final int? patientId = widget.patientId;

    if (patientId == null) {
      return registros;
    }

    final String patientIdTexto = patientId.toString();
    final String? patientName = widget.patientName;
    final List<Map<String, String>> filtrados = registros.where((registro) {
      return _registroPerteneceAlPaciente(
        registro,
        patientIdTexto,
        patientName,
      );
    }).toList();

    return filtrados;
  }

  bool _registroPerteneceAlPaciente(
    Map<String, dynamic> registro,
    String patientId,
    String? patientName,
  ) {
    final String? normalizado = _leerTexto(registro['patient_id_normalizado']);

    if (normalizado != null &&
        _normalizarIdPaciente(normalizado) == patientId) {
      return true;
    }

    final String patientIdRegistro = _extraerPatientIdRegistro(registro);
    if (_normalizarIdPaciente(patientIdRegistro) == patientId) {
      return true;
    }

    final String nombreObjetivo = _normalizarNombrePaciente(patientName);
    if (nombreObjetivo.isEmpty) {
      return false;
    }

    return _extraerNombresRegistro(registro).any((nombre) {
      return _normalizarNombrePaciente(nombre) == nombreObjetivo;
    });
  }

  String _extraerPatientIdRegistro(Map<String, dynamic> registro) {
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

  String _normalizarIdPaciente(String valor) {
    return valor
        .replaceFirst(RegExp(r'^Paciente:\s*', caseSensitive: false), '')
        .trim();
  }

  List<String> _extraerNombresRegistro(Map<String, dynamic> registro) {
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

  String _normalizarNombrePaciente(String? valor) {
    return (valor ?? '')
        .replaceFirst(RegExp(r'^Paciente:\s*', caseSensitive: false), '')
        .trim()
        .toLowerCase();
  }

  List<Map<String, String>> _aplicarFiltrosPacienteFecha(
    List<Map<String, String>> registros,
  ) {
    final String? pacienteSeleccionado = _pacienteSeleccionadoFiltro;
    final DateTime? fechaFiltro = _fechaFiltro;

    return registros.where((registro) {
      final bool coincidePacienteSeleccionado =
          pacienteSeleccionado == null ||
          _coincidePacienteSeleccionado(registro, pacienteSeleccionado);
      final bool coincideFecha =
          fechaFiltro == null || _coincideFecha(registro, fechaFiltro);

      return coincidePacienteSeleccionado && coincideFecha;
    }).toList();
  }

  List<Map<String, String>> _aplicarFiltroEstado(
    List<Map<String, String>> registros,
    RegistroClinicoSemaforo? estadoSeleccionado,
  ) {
    if (estadoSeleccionado == null) {
      return registros;
    }

    return registros.where((registro) {
      return _estadoGeneralRegistro(registro) == estadoSeleccionado;
    }).toList();
  }

  bool _coincidePacienteSeleccionado(
    Map<String, String> registro,
    String pacienteSeleccionado,
  ) {
    final String pacienteRegistro = _normalizarTexto(registro['patient'] ?? '');
    final String seleccionadoNormalizado = _normalizarTexto(
      pacienteSeleccionado,
    );

    return pacienteRegistro == seleccionadoNormalizado;
  }

  List<String> _pacientesDisponibles(List<Map<String, String>> registros) {
    final Map<String, String> pacientesPorNombreNormalizado = {};

    for (final registro in registros) {
      final String nombre = _limpiarNombrePaciente(registro['patient'] ?? '');
      final String nombreNormalizado = _normalizarTexto(nombre);

      if (nombre.isNotEmpty && nombreNormalizado.isNotEmpty) {
        pacientesPorNombreNormalizado[nombreNormalizado] = nombre;
      }
    }

    final List<String> pacientes = pacientesPorNombreNormalizado.values
        .toList();
    pacientes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return pacientes;
  }

  List<RegistroClinicoSemaforo> _estadosDisponibles(
    List<Map<String, String>> registros,
  ) {
    final Set<RegistroClinicoSemaforo> estados = {};

    for (final registro in registros) {
      estados.add(_estadoGeneralRegistro(registro));
    }

    final List<RegistroClinicoSemaforo> estadosOrdenados = estados.toList();
    estadosOrdenados.sort((a, b) {
      return _ordenEstado(a).compareTo(_ordenEstado(b));
    });
    return estadosOrdenados;
  }

  RegistroClinicoSemaforo _estadoGeneralRegistro(Map<String, String> registro) {
    return RegistroClinicoSemaforoHelper.calcular(registro).semaforo;
  }

  int _ordenEstado(RegistroClinicoSemaforo estado) {
    switch (estado) {
      case RegistroClinicoSemaforo.estable:
        return 0;
      case RegistroClinicoSemaforo.atencion:
        return 1;
      case RegistroClinicoSemaforo.alerta:
        return 2;
      case RegistroClinicoSemaforo.sinDato:
        return 3;
    }
  }

  bool _coincideFecha(Map<String, String> registro, DateTime fechaFiltro) {
    final DateTime? fechaRegistro = RegistrosClinicosService.leerFechaRegistro(
      registro,
    );

    if (fechaRegistro == null) {
      return false;
    }

    return _mismoDia(fechaRegistro, fechaFiltro);
  }

  bool _mismoDia(DateTime primeraFecha, DateTime segundaFecha) {
    return primeraFecha.year == segundaFecha.year &&
        primeraFecha.month == segundaFecha.month &&
        primeraFecha.day == segundaFecha.day;
  }

  String _normalizarTexto(String valor) {
    return _limpiarNombrePaciente(valor).toLowerCase().trim();
  }

  String _limpiarNombrePaciente(String valor) {
    final String sinPrefijo = valor.replaceFirst(
      RegExp(r'^Paciente:\s*', caseSensitive: false),
      '',
    );
    return sinPrefijo.trim();
  }

  Future<void> _seleccionarFecha() async {
    final DateTime ahora = DateTime.now();
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? widget.fechaFiltrada ?? ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Filtrar por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );

    if (fechaSeleccionada == null || !mounted) {
      return;
    }

    setState(() {
      _fechaFiltro = fechaSeleccionada;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _pacienteSeleccionadoFiltro = null;
      _estadoSeleccionadoFiltro = null;
      _fechaFiltro = null;
    });
  }

  void _seleccionarPacienteFiltro(String? paciente) {
    setState(() {
      _pacienteSeleccionadoFiltro = paciente;
    });
  }

  void _limpiarPacienteSeleccionado() {
    setState(() {
      _pacienteSeleccionadoFiltro = null;
    });
  }

  void _seleccionarEstadoFiltro(RegistroClinicoSemaforo? estado) {
    setState(() {
      _estadoSeleccionadoFiltro = estado;
    });
  }

  void _abrirDetalleRegistro(Map<String, String> registro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleRegistroClinico(registro: registro),
      ),
    );
  }

  String get _tituloPantalla {
    final DateTime? fechaFiltrada = widget.fechaFiltrada;

    if (fechaFiltrada != null) {
      return 'Registros del ${_formatearFechaTitulo(fechaFiltrada)}';
    }

    final String? patientName = widget.patientName?.trim();

    if (widget.patientId != null &&
        patientName != null &&
        patientName.isNotEmpty) {
      return 'Registros de $patientName';
    }

    if (_esRolCuidador) {
      return 'Registros clínicos vinculados';
    }

    return 'Mis registros clínicos';
  }

  bool get _esRolCuidador {
    final String roleNormalizado = _role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }

  bool get _mostrarPacienteEnTarjetas {
    return widget.patientId == null;
  }

  bool get _mostrarFiltroPaciente {
    return widget.patientId == null;
  }

  bool get _hayFiltrosActivos {
    return _pacienteSeleccionadoFiltro != null ||
        _fechaFiltro != null ||
        _estadoSeleccionadoFiltro != null;
  }

  String get _mensajeVacio {
    if (_hayFiltrosActivos) {
      return 'No hay registros clínicos con los filtros seleccionados.';
    }

    if (widget.fechaFiltrada != null) {
      return 'No hay registros clínicos en este día.';
    }

    if (widget.patientId != null) {
      return 'No hay registros para este paciente.';
    }

    return 'No hay registros clínicos.';
  }

  String _formatearFechaTitulo(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia-$mes-${fecha.year}';
  }

  String _formatearFechaFiltro(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia-$mes-${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clinicalBackground,
      appBar: AppBar(
        backgroundColor: _clinicalHeaderBlue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _tituloPantalla,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, String>>>(
          future: _registrosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ScreenLoading(
                message: 'Cargando mis registros clínicos...',
              );
            }

            final registrosReales = snapshot.hasError
                ? <Map<String, String>>[]
                : (snapshot.data ?? <Map<String, String>>[]);
            final registrosBase = registrosReales;
            final registrosPorPaciente = _filtrarRegistrosPorPaciente(
              registrosBase,
            );
            final pacientesDisponibles = _pacientesDisponibles(
              registrosPorPaciente,
            );
            final registrosPacienteFecha = _aplicarFiltrosPacienteFecha(
              registrosPorPaciente,
            );
            final estadosDisponibles = _estadosDisponibles(
              registrosPacienteFecha,
            );
            final RegistroClinicoSemaforo? estadoSeleccionadoValido =
                estadosDisponibles.contains(_estadoSeleccionadoFiltro)
                ? _estadoSeleccionadoFiltro
                : null;
            final registros = _aplicarFiltroEstado(
              registrosPacienteFecha,
              estadoSeleccionadoValido,
            );
            final bool mostrarFiltros = registrosPorPaciente.isNotEmpty;

            return Column(
              children: [
                if (mostrarFiltros)
                  _RecordFiltersCard(
                    mostrarBusquedaPaciente: _mostrarFiltroPaciente,
                    pacientesDisponibles: pacientesDisponibles,
                    pacienteSeleccionado: _pacienteSeleccionadoFiltro,
                    estadosDisponibles: estadosDisponibles,
                    estadoSeleccionado: estadoSeleccionadoValido,
                    fechaFiltro: _fechaFiltro,
                    fechaTexto: _fechaFiltro == null
                        ? null
                        : _formatearFechaFiltro(_fechaFiltro!),
                    hayFiltrosActivos: _hayFiltrosActivos,
                    onPacienteSeleccionado: _seleccionarPacienteFiltro,
                    onLimpiarPacienteSeleccionado: _limpiarPacienteSeleccionado,
                    onEstadoSeleccionado: _seleccionarEstadoFiltro,
                    onSeleccionarFecha: _seleccionarFecha,
                    onLimpiarFiltros: _limpiarFiltros,
                  ),
                Expanded(
                  child: registros.isEmpty
                      ? _EmptyRecordsState(message: _mensajeVacio)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: registros.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final registro = registros[index];
                            return _VitalRecordCard(
                              registro: registro,
                              showPatient: _mostrarPacienteEnTarjetas,
                              onTap: () => _abrirDetalleRegistro(registro),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScreenLoading extends StatelessWidget {
  const _ScreenLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                color: _clinicalTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordFiltersCard extends StatelessWidget {
  const _RecordFiltersCard({
    required this.mostrarBusquedaPaciente,
    required this.pacientesDisponibles,
    required this.pacienteSeleccionado,
    required this.estadosDisponibles,
    required this.estadoSeleccionado,
    required this.fechaFiltro,
    required this.fechaTexto,
    required this.hayFiltrosActivos,
    required this.onPacienteSeleccionado,
    required this.onLimpiarPacienteSeleccionado,
    required this.onEstadoSeleccionado,
    required this.onSeleccionarFecha,
    required this.onLimpiarFiltros,
  });

  final bool mostrarBusquedaPaciente;
  final List<String> pacientesDisponibles;
  final String? pacienteSeleccionado;
  final List<RegistroClinicoSemaforo> estadosDisponibles;
  final RegistroClinicoSemaforo? estadoSeleccionado;
  final DateTime? fechaFiltro;
  final String? fechaTexto;
  final bool hayFiltrosActivos;
  final ValueChanged<String?> onPacienteSeleccionado;
  final VoidCallback onLimpiarPacienteSeleccionado;
  final ValueChanged<RegistroClinicoSemaforo?> onEstadoSeleccionado;
  final VoidCallback onSeleccionarFecha;
  final VoidCallback onLimpiarFiltros;

  @override
  Widget build(BuildContext context) {
    final String textoFecha = fechaFiltro == null
        ? 'Filtrar por fecha'
        : 'Fecha: ${fechaTexto ?? ''}';
    final String? pacienteSeleccionadoValido =
        pacienteSeleccionado != null &&
            pacientesDisponibles.contains(pacienteSeleccionado)
        ? pacienteSeleccionado
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        0,
      ),
      child: EcronoCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mostrarBusquedaPaciente && pacientesDisponibles.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(pacienteSeleccionadoValido),
                initialValue: pacienteSeleccionadoValido,
                isExpanded: true,
                items: pacientesDisponibles.map((paciente) {
                  return DropdownMenuItem<String>(
                    value: paciente,
                    child: Text(paciente, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: onPacienteSeleccionado,
                style: const TextStyle(
                  fontSize: 14,
                  color: _clinicalTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Seleccionar paciente',
                  prefixIcon: const Icon(
                    Icons.person_search,
                    color: _clinicalTextSecondary,
                    size: 18,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon: pacienteSeleccionadoValido == null
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar selección',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: onLimpiarPacienteSeleccionado,
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: _clinicalBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: _clinicalBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(
                      color: _clinicalHeaderBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final bool usarWrap = constraints.maxWidth < 360;
                final Widget botonFecha = _CompactFilterButton(
                  text: textoFecha,
                  icon: Icons.calendar_today,
                  onPressed: onSeleccionarFecha,
                );
                final Widget selectorEstado = _EstadoFilterDropdown(
                  estadosDisponibles: estadosDisponibles,
                  estadoSeleccionado: estadoSeleccionado,
                  onChanged: onEstadoSeleccionado,
                );
                final Widget botonLimpiar = _CompactFilterButton(
                  text: 'Limpiar filtros',
                  icon: Icons.filter_alt_off,
                  onPressed: hayFiltrosActivos ? onLimpiarFiltros : null,
                );

                if (usarWrap) {
                  final double anchoDoble = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: anchoDoble, child: botonFecha),
                      SizedBox(width: anchoDoble, child: selectorEstado),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: botonLimpiar,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: botonFecha),
                    const SizedBox(width: 8),
                    Expanded(child: selectorEstado),
                    const SizedBox(width: 8),
                    Expanded(child: botonLimpiar),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoFilterDropdown extends StatelessWidget {
  const _EstadoFilterDropdown({
    required this.estadosDisponibles,
    required this.estadoSeleccionado,
    required this.onChanged,
  });

  final List<RegistroClinicoSemaforo> estadosDisponibles;
  final RegistroClinicoSemaforo? estadoSeleccionado;
  final ValueChanged<RegistroClinicoSemaforo?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: DropdownButtonFormField<RegistroClinicoSemaforo?>(
        initialValue: estadoSeleccionado,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: [
          const DropdownMenuItem<RegistroClinicoSemaforo?>(
            value: null,
            child: Text('Estado', overflow: TextOverflow.ellipsis),
          ),
          ...estadosDisponibles.map((estado) {
            return DropdownMenuItem<RegistroClinicoSemaforo?>(
              value: estado,
              child: Text(
                _etiquetaEstado(estado),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: estadosDisponibles.isEmpty ? null : onChanged,
        style: const TextStyle(fontSize: 13, color: _clinicalTextPrimary),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.traffic,
            color: _clinicalTextSecondary,
            size: 17,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: _clinicalBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: _clinicalBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(
              color: _clinicalHeaderBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  static String _etiquetaEstado(RegistroClinicoSemaforo estado) {
    switch (estado) {
      case RegistroClinicoSemaforo.estable:
        return 'Estable';
      case RegistroClinicoSemaforo.atencion:
        return 'Atención';
      case RegistroClinicoSemaforo.alerta:
        return 'Alerta';
      case RegistroClinicoSemaforo.sinDato:
        return 'Sin datos';
    }
  }
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _clinicalHeaderBlue,
          disabledForegroundColor: _clinicalTextSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: _clinicalBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyRecordsState extends StatelessWidget {
  const _EmptyRecordsState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: EcronoCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy,
                color: _clinicalHeaderBlue,
                size: 38,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _clinicalTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalRecordCard extends StatelessWidget {
  const _VitalRecordCard({
    required this.registro,
    required this.onTap,
    this.showPatient = true,
  });

  final Map<String, String> registro;
  final VoidCallback onTap;
  final bool showPatient;

  @override
  Widget build(BuildContext context) {
    final RegistroClinicoEstado estado = RegistroClinicoSemaforoHelper.calcular(
      registro,
    );
    final RegistroClinicoSemaforo estadoPresion =
        RegistroClinicoSemaforoHelper.evaluarPresionArterial(registro);
    final RegistroClinicoSemaforo estadoFrecuencia =
        RegistroClinicoSemaforoHelper.evaluarFrecuenciaCardiaca(registro);
    final RegistroClinicoSemaforo estadoGlucosa =
        RegistroClinicoSemaforoHelper.evaluarGlucosa(registro);
    final String frecuenciaTexto =
        registro['frecuencia_cardiaca'] == 'No informado'
        ? 'No informado'
        : '${registro['frecuencia_cardiaca']} bpm';
    final String presionTexto =
        '${registro['presion_sistolica']}/${registro['presion_diastolica']} mmHg';
    final String glucosaTexto =
        registro['glucosa'] == null || registro['glucosa'] == 'No informado'
        ? 'No informado'
        : '${registro['glucosa']} mg/dL';
    final String patientName = _nombrePaciente();
    final bool estaPendiente = registro['sync_status'] == 'pending';

    return Semantics(
      button: true,
      label: 'Ver detalle del registro clínico',
      child: GestureDetector(
        onTap: onTap,
        child: EcronoCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _clinicalSoftBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      color: _clinicalHeaderBlue,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showPatient) ...[
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Paciente: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: patientName),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: _clinicalTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          registro['fecha'] ?? 'No disponible',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: _clinicalTextPrimary,
                          ),
                        ),
                        if (estaPendiente) ...[
                          const SizedBox(height: 4),
                          const _PendingSyncInlineBadge(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  EcronoStatusBadge(text: estado.texto, status: estado.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SummaryMetricChip(
                          icon: Icons.favorite,
                          label: 'PA',
                          value: presionTexto,
                          semaforo: estadoPresion,
                        ),
                        _SummaryMetricChip(
                          icon: Icons.monitor_heart,
                          label: 'FC',
                          value: frecuenciaTexto,
                          semaforo: estadoFrecuencia,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SummaryMetricChip(
                    icon: Icons.bloodtype,
                    label: 'Glucosa',
                    value: glucosaTexto,
                    semaforo: estadoGlucosa,
                  ),
                  const Spacer(),
                  _SummaryDetailAction(onTap: onTap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nombrePaciente() {
    final String patient = registro['patient']?.trim() ?? '';

    if (patient.isEmpty) {
      return 'No disponible';
    }

    final String sinPrefijo = patient.replaceFirst(
      RegExp(r'^Paciente:\s*', caseSensitive: false),
      '',
    );
    final String limpio = sinPrefijo.trim();
    return limpio.isEmpty ? 'No disponible' : limpio;
  }
}

class _SummaryDetailAction extends StatelessWidget {
  const _SummaryDetailAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _clinicalBorder),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 14,
              color: _clinicalHeaderBlue,
            ),
            SizedBox(width: 4),
            Text(
              'Ver detalle',
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: _clinicalHeaderBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingSyncInlineBadge extends StatelessWidget {
  const _PendingSyncInlineBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.sync_problem, size: 13, color: AppTheme.pendingOrange),
        SizedBox(width: 4),
        Text(
          'Pendiente de sincronizar',
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppTheme.pendingOrange,
          ),
        ),
      ],
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.semaforo,
  });

  final IconData icon;
  final String label;
  final String value;
  final RegistroClinicoSemaforo semaforo;

  @override
  Widget build(BuildContext context) {
    final _MetricChipStyle style = _styleForSemaforo(semaforo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: style.foreground),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: style.foreground,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: style.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MetricChipStyle _styleForSemaforo(RegistroClinicoSemaforo semaforo) {
    switch (semaforo) {
      case RegistroClinicoSemaforo.estable:
        return _MetricChipStyle(
          foreground: AppTheme.successGreen,
          text: _clinicalTextPrimary,
          background: AppTheme.successGreen.withValues(alpha: 0.1),
          border: AppTheme.successGreen.withValues(alpha: 0.26),
        );
      case RegistroClinicoSemaforo.atencion:
        return _MetricChipStyle(
          foreground: AppTheme.pendingOrange,
          text: _clinicalTextPrimary,
          background: AppTheme.pendingOrange.withValues(alpha: 0.12),
          border: AppTheme.pendingOrange.withValues(alpha: 0.28),
        );
      case RegistroClinicoSemaforo.alerta:
        return _MetricChipStyle(
          foreground: AppTheme.alertRed,
          text: _clinicalTextPrimary,
          background: AppTheme.alertRed.withValues(alpha: 0.1),
          border: AppTheme.alertRed.withValues(alpha: 0.28),
        );
      case RegistroClinicoSemaforo.sinDato:
        return const _MetricChipStyle(
          foreground: _clinicalTextSecondary,
          text: _clinicalTextPrimary,
          background: Color(0xFFF9FAFB),
          border: _clinicalBorder,
        );
    }
  }
}

class _MetricChipStyle {
  const _MetricChipStyle({
    required this.foreground,
    required this.text,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color text;
  final Color background;
  final Color border;
}
