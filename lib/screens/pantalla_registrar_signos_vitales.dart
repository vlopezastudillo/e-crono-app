import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../api_constants.dart';
import '../services/offline_vital_signs_service.dart';
import '../services/pacientes_cuidador_service.dart';
import '../session_expired_handler.dart';
import '../session_helper.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
const Color _clinicalTextPrimary = Color(0xFF111827);
const TextStyle _headerTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 22,
  fontWeight: FontWeight.w700,
);
const TextStyle _screenTitleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 18,
  fontWeight: FontWeight.w700,
);
const TextStyle _screenSubtitleStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 14,
  fontWeight: FontWeight.normal,
  height: 1.35,
);
const TextStyle _patientNameStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 17,
  fontWeight: FontWeight.w700,
);
const TextStyle _patientDataStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 13,
  fontWeight: FontWeight.normal,
  height: 1.35,
);
const TextStyle _fieldTitleStyle = TextStyle(
  color: Color(0xFF0A2B4E),
  fontSize: 13,
  fontWeight: FontWeight.w600,
);
const TextStyle _hintSmallStyle = TextStyle(
  color: Color(0xFF9CA3AF),
  fontSize: 11,
  fontWeight: FontWeight.normal,
);

// Pantalla simple para registrar signos vitales.
class PantallaRegistrarSignosVitales extends StatefulWidget {
  const PantallaRegistrarSignosVitales({
    super.key,
    this.patientId,
    this.patientName,
  });

  final int? patientId;
  final String? patientName;

  @override
  State<PantallaRegistrarSignosVitales> createState() =>
      _PantallaRegistrarSignosVitalesState();
}

class _PantallaRegistrarSignosVitalesState
    extends State<PantallaRegistrarSignosVitales> {
  final PacientesCuidadorService _pacientesService =
      const PacientesCuidadorService();
  TextEditingController? _presionSistolicaController;
  TextEditingController? _presionDiastolicaController;
  TextEditingController? _frecuenciaCardiacaController;
  TextEditingController? _glucosaController;
  TextEditingController? _observacionesController;
  late Future<String?> _roleFuture;
  late Future<List<Map<String, String>>> _pacientesFuture;
  int? _selectedPatientId;
  String? _selectedPatientName;
  bool _guardandoRegistro = false;
  bool _sincronizandoPendientes = false;
  bool _manejandoSesionExpirada = false;
  int _registrosPendientesSincronizacion = 0;

  TextEditingController get _presionSistolicaInputController =>
      _presionSistolicaController ??= TextEditingController();
  TextEditingController get _presionDiastolicaInputController =>
      _presionDiastolicaController ??= TextEditingController();
  TextEditingController get _frecuenciaCardiacaInputController =>
      _frecuenciaCardiacaController ??= TextEditingController();
  TextEditingController get _glucosaInputController =>
      _glucosaController ??= TextEditingController();
  TextEditingController get _observacionesInputController =>
      _observacionesController ??= TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializa los controllers antes de que los TextField intenten usarlos.
    _presionSistolicaController = TextEditingController();
    _presionDiastolicaController = TextEditingController();
    _frecuenciaCardiacaController = TextEditingController();
    _glucosaController = TextEditingController();
    _observacionesController = TextEditingController();
    _roleFuture = SessionHelper.getRole();
    _pacientesFuture = _cargarPacientesACargo();
    _selectedPatientId = widget.patientId;
    _selectedPatientName = widget.patientName;
    _cargarRegistrosPendientesSincronizacion();
  }

  @override
  void dispose() {
    _presionSistolicaController?.dispose();
    _presionDiastolicaController?.dispose();
    _frecuenciaCardiacaController?.dispose();
    _glucosaController?.dispose();
    _observacionesController?.dispose();
    super.dispose();
  }

  Future<void> _guardarRegistro() async {
    final String presionSistolicaTexto = _presionSistolicaInputController.text
        .trim();
    final String presionDiastolicaTexto = _presionDiastolicaInputController.text
        .trim();
    final String frecuenciaCardiacaTexto = _frecuenciaCardiacaInputController
        .text
        .trim();
    final String glucosaTexto = _glucosaInputController.text.trim();
    final String observaciones = _observacionesInputController.text.trim();

    // Validaciones preventivas antes de enviar el registro al backend.
    final int? presionSistolica = _leerEnteroObligatorio(
      presionSistolicaTexto,
      'La presión sistólica es obligatoria.',
    );
    if (presionSistolica == null) {
      return;
    }

    final int? presionDiastolica = _leerEnteroObligatorio(
      presionDiastolicaTexto,
      'La presión diastólica es obligatoria.',
    );
    if (presionDiastolica == null) {
      return;
    }

    final int? frecuenciaCardiaca = _leerEnteroOpcional(
      frecuenciaCardiacaTexto,
      'La frecuencia cardíaca debe ser un número.',
    );
    if (frecuenciaCardiacaTexto.isNotEmpty && frecuenciaCardiaca == null) {
      return;
    }

    final int? glucosa = _leerEnteroOpcional(
      glucosaTexto,
      'La glucosa debe ser un número.',
    );
    if (glucosaTexto.isNotEmpty && glucosa == null) {
      return;
    }

    final String? errorValidacion = _validarRangosClinicos(
      presionSistolica: presionSistolica,
      presionDiastolica: presionDiastolica,
      frecuenciaCardiaca: frecuenciaCardiaca,
      glucosa: glucosa,
      observaciones: observaciones,
    );
    if (errorValidacion != null) {
      _mostrarErrorValidacion(errorValidacion);
      return;
    }

    final int? patientIdParaRegistro = await _obtenerPatientIdParaRegistro();
    if (patientIdParaRegistro == null && await _usuarioActualEsCuidador()) {
      return;
    }

    setState(() {
      _guardandoRegistro = true;
    });

    final Map<String, dynamic>? datosRegistro;
    try {
      datosRegistro = await _construirDatosRegistroParaEnvio(
        presionSistolica: presionSistolica,
        presionDiastolica: presionDiastolica,
        frecuenciaCardiaca: frecuenciaCardiaca,
        glucosa: glucosa,
        observaciones: observaciones,
        patientIdParaRegistro: patientIdParaRegistro,
      );
    } on SessionExpiredException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _guardandoRegistro = false;
      });
      _manejarSesionExpirada(error);
      return;
    }

    if (datosRegistro == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _guardandoRegistro = false;
      });
      _mostrarErrorValidacion('No se pudo preparar el registro.');
      return;
    }

    final int? codigoEstadoHttp;
    try {
      codigoEstadoHttp = await _enviarRegistroAlBackend(
        datosRegistro: datosRegistro,
      );
    } on SessionExpiredException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _guardandoRegistro = false;
      });
      _manejarSesionExpirada(error);
      return;
    }
    final bool guardadoEnBackend =
        codigoEstadoHttp != null &&
        codigoEstadoHttp >= 200 &&
        codigoEstadoHttp < 300;
    bool guardadoLocalmente = false;
    int? registrosPendientesActualizados;

    if (!guardadoEnBackend) {
      guardadoLocalmente = await _guardarRegistroPendienteLocal(datosRegistro);
      if (guardadoLocalmente) {
        registrosPendientesActualizados =
            await _contarRegistrosRealesPendientes();
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _guardandoRegistro = false;
      if (registrosPendientesActualizados != null) {
        _registrosPendientesSincronizacion = registrosPendientesActualizados;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardadoEnBackend
              ? 'Registro guardado correctamente'
              : guardadoLocalmente
              ? 'Guardado sin conexión. Pendiente de sincronizar.'
              : 'No se pudo guardar el registro. Intente nuevamente.',
        ),
      ),
    );
    await AppNavigation.irAInicio(context);
  }

  int? _leerEnteroObligatorio(String texto, String mensajeVacio) {
    if (texto.isEmpty) {
      _mostrarErrorValidacion(mensajeVacio);
      return null;
    }

    final int? valor = int.tryParse(texto);
    if (valor == null) {
      _mostrarErrorValidacion('Ingresa solo números en los campos clínicos.');
    }

    return valor;
  }

  int? _leerEnteroOpcional(String texto, String mensajeInvalido) {
    if (texto.isEmpty) {
      return null;
    }

    final int? valor = int.tryParse(texto);
    if (valor == null) {
      _mostrarErrorValidacion(mensajeInvalido);
    }

    return valor;
  }

  String? _validarRangosClinicos({
    required int presionSistolica,
    required int presionDiastolica,
    required int? frecuenciaCardiaca,
    required int? glucosa,
    required String observaciones,
  }) {
    if (presionSistolica < 70 || presionSistolica > 250) {
      return 'La presión sistólica debe estar entre 70 y 250 mmHg.';
    }

    if (presionDiastolica < 40 || presionDiastolica > 150) {
      return 'La presión diastólica debe estar entre 40 y 150 mmHg.';
    }

    if (frecuenciaCardiaca != null &&
        (frecuenciaCardiaca < 40 || frecuenciaCardiaca > 180)) {
      return 'La frecuencia cardíaca debe estar entre 40 y 180 bpm.';
    }

    if (glucosa != null && (glucosa < 40 || glucosa > 500)) {
      return 'La glucosa debe estar entre 40 y 500 mg/dL.';
    }

    if (observaciones.length > 300) {
      return 'Las observaciones no pueden superar los 300 caracteres.';
    }

    return null;
  }

  void _mostrarErrorValidacion(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cargarRegistrosPendientesSincronizacion() async {
    final int cantidad = await _contarRegistrosRealesPendientes();

    if (!mounted) {
      return;
    }

    setState(() {
      _registrosPendientesSincronizacion = cantidad;
    });
  }

  Future<void> _sincronizarRegistrosPendientes() async {
    if (_sincronizandoPendientes) {
      return;
    }

    setState(() {
      _sincronizandoPendientes = true;
    });

    final List<Map<String, dynamic>> registrosPendientes =
        await OfflineVitalSignsService.obtenerRegistrosPendientes();
    final List<Map<String, dynamic>> registrosReales = registrosPendientes
        .where((registro) => registro['is_demo'] != 'true')
        .toList();
    bool huboFallas = false;

    for (final Map<String, dynamic> registro in registrosReales) {
      final String? localId = registro['local_id']?.toString().trim();
      if (localId == null || localId.isEmpty) {
        huboFallas = true;
        continue;
      }

      final Map<String, dynamic> datosRegistro =
          _prepararRegistroPendienteParaBackend(registro);
      final int? codigoEstadoHttp;
      try {
        codigoEstadoHttp = await _enviarRegistroAlBackend(
          datosRegistro: datosRegistro,
        );
      } on SessionExpiredException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _sincronizandoPendientes = false;
        });
        _manejarSesionExpirada(error);
        return;
      }
      final bool sincronizado =
          codigoEstadoHttp != null &&
          codigoEstadoHttp >= 200 &&
          codigoEstadoHttp < 300;

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

    final int cantidadActualizada = await _contarRegistrosRealesPendientes();

    if (!mounted) {
      return;
    }

    setState(() {
      _sincronizandoPendientes = false;
      _registrosPendientesSincronizacion = cantidadActualizada;
    });

    if (huboFallas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Algunos registros no pudieron sincronizarse'),
        ),
      );
    }
  }

  Future<int> _contarRegistrosRealesPendientes() async {
    final List<Map<String, dynamic>> registrosPendientes =
        await OfflineVitalSignsService.obtenerRegistrosPendientes();
    return registrosPendientes
        .where((registro) => registro['is_demo'] != 'true')
        .length;
  }

  Future<bool> _usuarioActualEsCuidador() async {
    final String? role = await SessionHelper.getRole();
    return _esRolCuidador(role);
  }

  Future<int?> _obtenerPatientIdParaRegistro() async {
    final String? role = await SessionHelper.getRole();
    final bool esCuidador = _esRolCuidador(role);

    if (!esCuidador) {
      return widget.patientId;
    }

    final int? patientId = widget.patientId ?? _selectedPatientId;

    if (patientId != null) {
      return patientId;
    }

    if (!mounted) {
      return null;
    }

    _mostrarErrorValidacion(
      'Selecciona un paciente antes de guardar el control.',
    );
    return null;
  }

  bool _esRolCuidador(String? role) {
    final String roleNormalizado = role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }

  void _abrirHistorialClinico() {
    final int? patientId = widget.patientId ?? _selectedPatientId;
    final String? patientName = widget.patientName ?? _selectedPatientName;
    final String patientNameLimpio = patientName?.trim() ?? '';

    if (patientId != null) {
      AppNavigation.abrirRegistrosPaciente(
        context,
        patientId: patientId,
        patientName: patientNameLimpio.isEmpty
            ? 'Paciente seleccionado'
            : patientNameLimpio,
      );
      return;
    }

    AppNavigation.abrirMisRegistros(context);
  }

  Future<Map<String, dynamic>?> _construirDatosRegistroParaEnvio({
    required int presionSistolica,
    required int presionDiastolica,
    required int? frecuenciaCardiaca,
    required int? glucosa,
    required String observaciones,
    required int? patientIdParaRegistro,
  }) async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();
      final bool haySesion = headers.containsKey('Authorization');
      final String? role = await SessionHelper.getRole();
      final bool esCuidador = _esRolCuidador(role);
      final int? patientIdGuardado = await SessionHelper.getPatientId();

      final Map<String, dynamic> datosRegistro = {
        // El backend asigna fecha_registro automáticamente con timezone.now().
        'presion_sistolica': presionSistolica,
        'presion_diastolica': presionDiastolica,
        'observaciones': observaciones,
      };

      if (frecuenciaCardiaca != null) {
        datosRegistro['frecuencia_cardiaca'] = frecuenciaCardiaca;
      }

      if (glucosa != null) {
        datosRegistro['glucosa'] = glucosa;
      }

      if (!haySesion) {
        throw const SessionExpiredException();
      }

      if (patientIdParaRegistro != null) {
        datosRegistro['patient'] = patientIdParaRegistro;
      } else if (!esCuidador) {
        // En el flujo paciente se mantiene el comportamiento actual.
        if (patientIdGuardado != null) {
          datosRegistro['patient'] = patientIdGuardado;
        }
      } else if (esCuidador) {
        return null;
      }

      return datosRegistro;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _enviarRegistroAlBackend({
    required Map<String, dynamic> datosRegistro,
  }) async {
    try {
      final String cuerpoJson = jsonEncode(datosRegistro);

      final response = await SessionHelper.authenticatedPost(
        Uri.parse(apiVitalSignRecordsUrl),
        body: cuerpoJson,
      );

      return response.statusCode;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, String>>> _cargarPacientesACargo() async {
    try {
      return await _pacientesService.cargarPacientesACargo();
    } on SessionExpiredException catch (error) {
      _manejarSesionExpirada(error);
      return [];
    }
  }

  void _manejarSesionExpirada(SessionExpiredException error) {
    if (_manejandoSesionExpirada) {
      return;
    }

    _manejandoSesionExpirada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      handleSessionExpired(context, error: error);
    });
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
    datosRegistro.remove('is_demo');
    return datosRegistro;
  }

  Future<bool> _guardarRegistroPendienteLocal(
    Map<String, dynamic> datosRegistro,
  ) async {
    final dynamic patient = datosRegistro['patient'];
    final String createdAtLocal = DateTime.now().toIso8601String();
    final Map<String, dynamic> registroPendiente = {
      ...datosRegistro,
      'local_id': 'vital_${patient}_${DateTime.now().millisecondsSinceEpoch}',
      'created_at_local': createdAtLocal,
      'sync_status': 'pending',
    };

    return OfflineVitalSignsService.guardarRegistroPendiente(registroPendiente);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clinicalBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 294,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 176,
                      width: double.infinity,
                      color: _clinicalHeaderBlue,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            tooltip: 'Volver',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 166,
                            height: 68,
                            child: Image.asset(
                              'assets/images/e-Crono_Logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Spacer(),
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('e-Crono', style: _headerTitleStyle),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 106,
                      child: _PatientSummaryCard(
                        roleFuture: _roleFuture,
                        patientId: widget.patientId ?? _selectedPatientId,
                        patientName: widget.patientName ?? _selectedPatientName,
                        onAbrirHistorial: _abrirHistorialClinico,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Control de Signos Vitales',
                      style: _screenTitleStyle,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Registre las mediciones de la atención en terreno',
                      style: _screenSubtitleStyle,
                    ),
                    const SizedBox(height: 16),
                    _CaregiverPatientTargetSection(
                      roleFuture: _roleFuture,
                      pacientesFuture: _pacientesFuture,
                      fixedPatientId: widget.patientId,
                      selectedPatientId: _selectedPatientId,
                      onPatientSelected: (patient) {
                        setState(() {
                          _selectedPatientId = patient?.id;
                          _selectedPatientName = patient?.name;
                        });
                      },
                    ),
                    _VitalSignCard(
                      icon: Icons.favorite,
                      title: 'Presión Arterial',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _presionSistolicaInputController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _clinicalTextPrimary,
                                  ),
                                  decoration: _vitalInputDecoration(
                                    hintText: 'Sistólica',
                                    unit: 'mmHg',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _presionDiastolicaInputController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _clinicalTextPrimary,
                                  ),
                                  decoration: _vitalInputDecoration(
                                    hintText: 'Diastólica',
                                    unit: 'mmHg',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Formato: sistólica/diastólica',
                              style: _hintSmallStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _VitalSignCard(
                      icon: Icons.bloodtype,
                      title: 'Niveles de Glucosa',
                      child: TextField(
                        controller: _glucosaInputController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _clinicalTextPrimary,
                        ),
                        decoration: _vitalInputDecoration(
                          hintText: 'Ej: 100',
                          unit: 'mg/dL',
                        ),
                      ),
                    ),
                    _VitalSignCard(
                      icon: Icons.monitor_heart,
                      title: 'Frecuencia cardíaca',
                      child: TextField(
                        controller: _frecuenciaCardiacaInputController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _clinicalTextPrimary,
                        ),
                        decoration: _vitalInputDecoration(
                          hintText: 'Ej: 75',
                          unit: 'bpm',
                        ),
                      ),
                    ),
                    _VitalSignCard(
                      icon: Icons.notes,
                      title: 'Observaciones',
                      child: TextField(
                        controller: _observacionesInputController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _clinicalTextPrimary,
                        ),
                        decoration: _vitalInputDecoration(
                          hintText: 'Ej: Control estable, sin síntomas.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    EcronoPrimaryButton(
                      text: 'Guardar registro',
                      icon: Icons.save_alt,
                      isLoading: _guardandoRegistro,
                      onPressed: _guardarRegistro,
                    ),
                    const SizedBox(height: 12),
                    const _OfflineNotice(),
                    if (_registrosPendientesSincronizacion > 0) ...[
                      const SizedBox(height: 8),
                      _PendingSyncNotice(
                        cantidad: _registrosPendientesSincronizacion,
                      ),
                      const SizedBox(height: 8),
                      EcronoSecondaryButton(
                        text: 'Sincronizar pendientes',
                        icon: Icons.sync,
                        onPressed: _sincronizandoPendientes
                            ? null
                            : _sincronizarRegistrosPendientes,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EcronoBottomNavigation(
        currentSection: EcronoBottomSection.salud,
        onSectionSelected: (destino) {
          AppNavigation.manejarBarraInferior(
            context,
            actual: EcronoBottomSection.salud,
            destino: destino,
          );
        },
      ),
    );
  }

  InputDecoration _vitalInputDecoration({
    required String hintText,
    String? unit,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _clinicalHeaderBlue, width: 1.5),
      ),
      suffixIcon: unit == null
          ? null
          : Center(
              widthFactor: 1,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({
    required this.roleFuture,
    required this.patientId,
    required this.patientName,
    required this.onAbrirHistorial,
  });

  final Future<String?> roleFuture;
  final int? patientId;
  final String? patientName;
  final VoidCallback onAbrirHistorial;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: roleFuture,
      builder: (context, snapshot) {
        final bool esCuidador = _esRolCuidador(snapshot.data);
        final String patientNameLimpio = patientName?.trim() ?? '';
        final bool tienePaciente = patientId != null;
        final String titulo = esCuidador
            ? tienePaciente
                  ? 'Registrando control para:'
                  : 'Selecciona un paciente para registrar el control'
            : 'Registrar mi control de salud';
        final String? detalle = esCuidador
            ? tienePaciente
                  ? (patientNameLimpio.isEmpty
                        ? 'Paciente seleccionado'
                        : patientNameLimpio)
                  : null
            : 'Completa tus signos vitales para actualizar tu historial.';

        return EcronoCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF3B82F6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: _patientNameStyle),
                        if (detalle != null) ...[
                          const SizedBox(height: 4),
                          Text(detalle, style: _patientDataStyle),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              EcronoSecondaryButton(
                text: 'Ver historial clínico',
                icon: Icons.description,
                onPressed: onAbrirHistorial,
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _esRolCuidador(String? role) {
    final String roleNormalizado = role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }
}

class _CaregiverPatientTargetSection extends StatelessWidget {
  const _CaregiverPatientTargetSection({
    required this.roleFuture,
    required this.pacientesFuture,
    required this.fixedPatientId,
    required this.selectedPatientId,
    required this.onPatientSelected,
  });

  final Future<String?> roleFuture;
  final Future<List<Map<String, String>>> pacientesFuture;
  final int? fixedPatientId;
  final int? selectedPatientId;
  final ValueChanged<_PatientOption?> onPatientSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: roleFuture,
      builder: (context, snapshot) {
        final bool esCuidador = _esRolCuidador(snapshot.data);

        if (!esCuidador) {
          return const SizedBox.shrink();
        }

        if (fixedPatientId != null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<Map<String, String>>>(
          future: pacientesFuture,
          builder: (context, patientSnapshot) {
            if (patientSnapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: EcronoCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cargando pacientes...',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final List<_PatientOption> patientOptions =
                (patientSnapshot.data ?? <Map<String, String>>[])
                    .map(_PatientOption.fromMap)
                    .whereType<_PatientOption>()
                    .toList();

            if (patientOptions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: EcronoCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, color: _clinicalHeaderBlue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No se encontraron pacientes disponibles para registrar el control.',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final Set<int> availableIds = patientOptions
                .map((patient) => patient.id)
                .toSet();
            final int? dropdownValue = availableIds.contains(selectedPatientId)
                ? selectedPatientId
                : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EcronoCard(
                child: DropdownButtonFormField<int>(
                  initialValue: dropdownValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Paciente',
                    prefixIcon: const Icon(
                      Icons.person,
                      color: _clinicalHeaderBlue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _clinicalHeaderBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                  hint: const Text('Selecciona un paciente'),
                  items: patientOptions.map((patient) {
                    return DropdownMenuItem<int>(
                      value: patient.id,
                      child: Text(patient.name),
                    );
                  }).toList(),
                  onChanged: (patientId) {
                    _PatientOption? selectedPatient;

                    for (final patient in patientOptions) {
                      if (patient.id == patientId) {
                        selectedPatient = patient;
                        break;
                      }
                    }

                    onPatientSelected(selectedPatient);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  static bool _esRolCuidador(String? role) {
    final String roleNormalizado = role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }
}

class _PatientOption {
  const _PatientOption({required this.id, required this.name});

  final int id;
  final String name;

  static _PatientOption? fromMap(Map<String, String> patient) {
    final int? id = int.tryParse(patient['patient_id'] ?? '');
    final String name = patient['patient'] ?? 'Paciente';

    if (id == null) {
      return null;
    }

    return _PatientOption(id: id, name: name);
  }
}

class _VitalSignCard extends StatelessWidget {
  const _VitalSignCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: EcronoCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: _clinicalHeaderBlue),
                const SizedBox(width: 8),
                Text(title, style: _fieldTitleStyle),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_iphone, color: Color(0xFF3B82F6), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF1E3A8A),
                ),
                children: [
                  TextSpan(text: 'Los datos quedarán almacenados y se '),
                  TextSpan(
                    text: 'sincronizarán',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' cuando haya conexión'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSyncNotice extends StatelessWidget {
  const _PendingSyncNotice({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem, color: Color(0xFFC2410C), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tienes $cantidad registro(s) pendiente(s) de sincronizar.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
