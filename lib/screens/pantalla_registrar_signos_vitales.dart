import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_navigation.dart';
import '../api_constants.dart';
import '../session_helper.dart';
import '../widgets/ecrono_bottom_navigation.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
const Color _clinicalBorder = Color(0xFFE5E7EB);
const Color _clinicalTextPrimary = Color(0xFF111827);
const TextStyle _headerTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);
const TextStyle _screenTitleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 20,
  fontWeight: FontWeight.bold,
);
const TextStyle _screenSubtitleStyle = TextStyle(
  color: Color(0xFF6B7280),
  fontSize: 14,
  fontWeight: FontWeight.normal,
  height: 1.35,
);
const TextStyle _patientNameStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontSize: 18,
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
  fontSize: 14,
  fontWeight: FontWeight.w600,
);
const TextStyle _hintSmallStyle = TextStyle(
  color: Color(0xFF9CA3AF),
  fontSize: 11,
  fontWeight: FontWeight.normal,
);

// Pantalla simple para registrar signos vitales en modo demo.
class PantallaRegistrarSignosVitales extends StatefulWidget {
  const PantallaRegistrarSignosVitales({super.key});

  @override
  State<PantallaRegistrarSignosVitales> createState() =>
      _PantallaRegistrarSignosVitalesState();
}

class _PantallaRegistrarSignosVitalesState
    extends State<PantallaRegistrarSignosVitales> {
  TextEditingController? _presionSistolicaController;
  TextEditingController? _presionDiastolicaController;
  TextEditingController? _frecuenciaCardiacaController;
  TextEditingController? _glucosaController;
  TextEditingController? _observacionesController;
  bool _guardandoRegistro = false;

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

    setState(() {
      _guardandoRegistro = true;
    });

    final int? codigoEstadoHttp = await _enviarRegistroAlBackend(
      presionSistolica: presionSistolica,
      presionDiastolica: presionDiastolica,
      frecuenciaCardiaca: frecuenciaCardiaca,
      glucosa: glucosa,
      observaciones: observaciones,
    );
    final bool guardadoEnBackend =
        codigoEstadoHttp != null &&
        codigoEstadoHttp >= 200 &&
        codigoEstadoHttp < 300;

    if (!mounted) {
      return;
    }

    setState(() {
      _guardandoRegistro = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardadoEnBackend
              ? 'Registro guardado correctamente'
              : 'Registro guardado en modo demo',
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

  Future<int?> _enviarRegistroAlBackend({
    required int presionSistolica,
    required int presionDiastolica,
    required int? frecuenciaCardiaca,
    required int? glucosa,
    required String observaciones,
  }) async {
    try {
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();
      final bool haySesion = headers.containsKey('Authorization');
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

      if (haySesion) {
        // En modo autenticado, el backend decide el paciente según el token.
        if (patientIdGuardado != null) {
          datosRegistro['patient'] = patientIdGuardado;
        }
      } else {
        // patient: 1 solo se conserva para modo demo sin sesión.
        datosRegistro['patient'] = 1;
      }

      final String cuerpoJson = jsonEncode(datosRegistro);

      debugPrint('POST signos vitales: JSON enviado $cuerpoJson');

      // Intenta guardar en el endpoint real antes de usar el modo demo.
      final response = await http.post(
        Uri.parse(apiVitalSignRecordsUrl),
        headers: headers,
        body: cuerpoJson,
      );

      debugPrint('POST signos vitales: estado HTTP ${response.statusCode}');
      debugPrint('POST signos vitales: respuesta ${response.body}');
      return response.statusCode;
    } catch (_) {
      // Si falla el backend o no hay sesion, se mantiene el fallback demo.
      return null;
    }
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
                        onAbrirHistorial: () {
                          AppNavigation.abrirMisRegistros(context);
                        },
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _guardandoRegistro ? null : _guardarRegistro,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _clinicalHeaderBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _clinicalHeaderBlue
                              .withValues(alpha: 0.65),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        icon: _guardandoRegistro
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_alt),
                        label: const Text(
                          'Guardar Registro Local',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _OfflineNotice(),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
  const _PatientSummaryCard({required this.onAbrirHistorial});

  final VoidCallback onAbrirHistorial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _clinicalBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF3B82F6),
                  size: 36,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('María Ester Silva', style: _patientNameStyle),
                    SizedBox(height: 4),
                    Text(
                      '72 años - RUT: 6.372.XXX-X',
                      style: _patientDataStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton(
              onPressed: onAbrirHistorial,
              style: OutlinedButton.styleFrom(
                foregroundColor: _clinicalHeaderBlue,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text(
                'Ver historial clínico',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: _clinicalHeaderBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          const SizedBox(height: 12),
          child,
        ],
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
