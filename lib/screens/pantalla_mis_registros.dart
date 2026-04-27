import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_constants.dart';
import '../route_observer.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
const Color _clinicalBorder = Color(0xFFE5E7EB);
const Color _clinicalTextPrimary = Color(0xFF111827);
const Color _clinicalTextSecondary = Color(0xFF6B7280);
const Color _clinicalTextTertiary = Color(0xFF374151);
const Color _clinicalAlert = Color(0xFFEF4444);
const Color _clinicalWarning = Color(0xFFF59E0B);
const Color _clinicalSoftBlue = Color(0xFFEFF6FF);

// Pantalla simple para listar los registros clinicos del paciente.
class PantallaMisRegistros extends StatefulWidget {
  const PantallaMisRegistros({super.key});

  @override
  State<PantallaMisRegistros> createState() => _PantallaMisRegistrosState();
}

class _PantallaMisRegistrosState extends State<PantallaMisRegistros>
    with RouteAware {
  late Future<List<Map<String, String>>> _registrosFuture;
  bool _suscritoARuta = false;

  @override
  void initState() {
    super.initState();
    // Carga la lista de registros al abrir la pantalla.
    _registrosFuture = _cargarRegistros();
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
      _registrosFuture = _cargarRegistros();
    });
  }

  Future<List<Map<String, String>>> _cargarRegistros() async {
    try {
      // Usa el token guardado; sin sesión se conserva el fallback demo.
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

      // Ordena por fecha_registro real: más recientes primero.
      registros.sort(_compararRegistrosPorFechaDescendente);

      return registros.map((registro) {
        final dynamic patientData = registro['patient'];
        final dynamic registradoPorData = registro['registrado_por'];

        final String patient = patientData is Map<String, dynamic>
            ? patientData['username']?.toString() ??
                  patientData['name']?.toString() ??
                  patientData['id']?.toString() ??
                  'No disponible'
            : patientData?.toString() ?? 'No disponible';

        final String? registradoPor = registradoPorData is Map<String, dynamic>
            ? _leerTexto(registradoPorData['username']) ??
                  _leerTexto(registradoPorData['name']) ??
                  _leerTexto(registradoPorData['id'])
            : _leerTexto(registradoPorData);
        final String fechaOriginal =
            registro['fecha_registro']?.toString() ??
            registro['fecha']?.toString() ??
            registro['date']?.toString() ??
            registro['created_at']?.toString() ??
            'No disponible';

        final Map<String, String> registroParseado = {
          'patient': patient,
          'fecha': _formatearFechaRegistro(fechaOriginal),
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

        if (registradoPor != null) {
          registroParseado['registrado_por'] = registradoPor;
        }

        return registroParseado;
      }).toList();
    } catch (_) {
      // Si la API falla, la pantalla mantiene los datos demo.
      return [];
    }
  }

  int _compararRegistrosPorFechaDescendente(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final DateTime? fechaA = _leerFechaRegistro(a);
    final DateTime? fechaB = _leerFechaRegistro(b);

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

  DateTime? _leerFechaRegistro(Map<String, dynamic> registro) {
    final String? fecha = _leerTexto(registro['fecha_registro']);

    if (fecha == null) {
      return null;
    }

    try {
      return DateTime.parse(fecha);
    } catch (_) {
      // Si alguna fecha falla, ese registro queda al final de la lista.
      return null;
    }
  }

  String _formatearFechaRegistro(String fechaOriginal) {
    late final DateTime fechaLocal;

    try {
      // Convierte la fecha ISO/UTC del backend a la hora local del dispositivo.
      fechaLocal = DateTime.parse(fechaOriginal).toLocal();
    } catch (_) {
      return fechaOriginal;
    }

    // Muestra fechas ISO como 26-04-2026 17:38; si no parsea, queda original.
    final String dia = _dosDigitos(fechaLocal.day);
    final String mes = _dosDigitos(fechaLocal.month);
    final String hora = _dosDigitos(fechaLocal.hour);
    final String minuto = _dosDigitos(fechaLocal.minute);

    return '$dia-$mes-${fechaLocal.year} $hora:$minuto';
  }

  String _dosDigitos(int valor) {
    return valor.toString().padLeft(2, '0');
  }

  String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  // Lista local de apoyo para mostrar una demo si la API no trae datos.
  List<Map<String, String>> _obtenerRegistrosDemo() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clinicalBackground,
      appBar: AppBar(
        backgroundColor: _clinicalHeaderBlue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mis registros clínicos',
          style: TextStyle(
            fontSize: 18,
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
            final bool usandoDatosDemo = registrosReales.isEmpty;
            final registros = usandoDatosDemo
                ? _obtenerRegistrosDemo()
                : registrosReales;

            return Column(
              children: [
                if (usandoDatosDemo)
                  const _DemoNotice(
                    message:
                        'Mostrando datos demo porque la API no devolvió registros clínicos.',
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: registros.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final registro = registros[index];
                      return _VitalRecordCard(
                        registro: registro,
                        showPatient: false,
                        isDemo: usandoDatosDemo,
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

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingLg,
        AppTheme.spacingLg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _clinicalBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: _clinicalHeaderBlue),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: _clinicalTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalMetricRow extends StatelessWidget {
  const _ClinicalMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: _clinicalTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: _clinicalTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VitalRecordCard extends StatelessWidget {
  const _VitalRecordCard({
    required this.registro,
    this.showPatient = true,
    this.isDemo = false,
  });

  final Map<String, String> registro;
  final bool showPatient;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final String frecuenciaTexto =
        registro['frecuencia_cardiaca'] == 'No informado'
        ? 'No informado'
        : '${registro['frecuencia_cardiaca']} bpm';
    final String presionTexto =
        '${registro['presion_sistolica']}/${registro['presion_diastolica']} mmHg';
    final bool mostrarGlucosa =
        registro['glucosa'] != null && registro['glucosa'] != 'No informado';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _clinicalBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _clinicalSoftBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: _clinicalHeaderBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPatient)
                      Text(
                        registro['patient'] ?? 'Paciente',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _clinicalTextPrimary,
                        ),
                      ),
                    Text(
                      registro['fecha'] ?? 'No disponible',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: _clinicalTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDemo)
                const EcronoStatusBadge(
                  text: 'Demo',
                  status: EcronoStatusType.info,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ClinicalMetricRow(
            icon: Icons.favorite,
            iconColor: _clinicalAlert,
            iconBackground: const Color(0xFFFEF2F2),
            label: 'Presión arterial',
            value: presionTexto,
          ),
          const SizedBox(height: 12),
          _ClinicalMetricRow(
            icon: Icons.monitor_heart,
            iconColor: AppTheme.actionBlue,
            iconBackground: _clinicalSoftBlue,
            label: 'Frecuencia cardíaca',
            value: frecuenciaTexto,
          ),
          if (mostrarGlucosa) ...[
            const SizedBox(height: 12),
            _ClinicalMetricRow(
              icon: Icons.bloodtype,
              iconColor: _clinicalWarning,
              iconBackground: const Color(0xFFFFFBEB),
              label: 'Glucosa',
              value: '${registro['glucosa']} mg/dL',
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: _clinicalBorder),
          const SizedBox(height: 14),
          const Text(
            'Observaciones',
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: _clinicalTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            registro['observaciones'] ?? 'Sin observaciones',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
              color: _clinicalTextTertiary,
            ),
          ),
          if (registro['registrado_por'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: _clinicalTextSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Registrado por: ${registro['registrado_por']}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      color: _clinicalTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
