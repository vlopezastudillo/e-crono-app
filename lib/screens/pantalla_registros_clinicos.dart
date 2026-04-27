import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_constants.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
const Color _clinicalBorder = Color(0xFFE5E7EB);
const Color _clinicalTextPrimary = Color(0xFF111827);
const Color _clinicalTextSecondary = Color(0xFF6B7280);
const Color _clinicalAlert = Color(0xFFEF4444);
const Color _clinicalWarning = Color(0xFFF59E0B);

// Pantalla simple para listar registros clinicos del cuidador.
class PantallaRegistrosClinicos extends StatefulWidget {
  const PantallaRegistrosClinicos({super.key});

  @override
  State<PantallaRegistrosClinicos> createState() =>
      _PantallaRegistrosClinicosState();
}

class _PantallaRegistrosClinicosState extends State<PantallaRegistrosClinicos> {
  late Future<List<Map<String, String>>> _registrosFuture;

  @override
  void initState() {
    super.initState();
    // Carga la lista de registros al abrir la pantalla.
    _registrosFuture = _cargarRegistros();
  }

  Future<List<Map<String, String>>> _cargarRegistros() async {
    try {
      // Envia Authorization: Token <token> cuando hay login real guardado.
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();
      final response = await http.get(
        Uri.parse(apiVitalSignRecordsUrl),
        headers: headers,
      );

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

      return items.whereType<Map<String, dynamic>>().map((registro) {
        final dynamic patientData = registro['patient'];

        final String patient = patientData is Map<String, dynamic>
            ? patientData['username']?.toString() ??
                  patientData['name']?.toString() ??
                  patientData['id']?.toString() ??
                  'No disponible'
            : patientData?.toString() ?? 'No disponible';

        return {
          'patient': patient,
          'fecha':
              registro['fecha_registro']?.toString() ??
              registro['fecha']?.toString() ??
              registro['date']?.toString() ??
              registro['created_at']?.toString() ??
              'No disponible',
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
              'No disponible',
          'glucosa':
              registro['glucosa']?.toString() ??
              registro['glucose']?.toString() ??
              'No disponible',
          'observaciones':
              registro['observaciones']?.toString() ??
              registro['notes']?.toString() ??
              'Sin observaciones',
        };
      }).toList();
    } catch (_) {
      // Si falla la API, no se rompe el flujo demo.
      return [];
    }
  }

  // Lista local de apoyo para mostrar una demo si la API no trae datos.
  List<Map<String, String>> _obtenerRegistrosDemo() {
    return const [
      {
        'fecha': '24/04/2026',
        'patient': 'María González',
        'presion_sistolica': '124',
        'presion_diastolica': '78',
        'frecuencia_cardiaca': '73',
        'observaciones': 'Control estable, continuar tratamiento habitual.',
      },
      {
        'fecha': '21/04/2026',
        'patient': 'Juan Pérez',
        'presion_sistolica': '136',
        'presion_diastolica': '84',
        'frecuencia_cardiaca': '82',
        'observaciones': 'Requiere seguimiento por cifras elevadas.',
      },
      {
        'fecha': '18/04/2026',
        'patient': 'María González',
        'presion_sistolica': '120',
        'presion_diastolica': '76',
        'frecuencia_cardiaca': '71',
        'observaciones': 'Sin síntomas de alarma reportados.',
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
        title: const Text('Registros clínicos asociados'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, String>>>(
          future: _registrosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ScreenLoading(
                message: 'Cargando registros clínicos asociados...',
              );
            }

            if (snapshot.hasError) {
              return const _ScreenError(
                message: 'No fue posible cargar los registros clínicos.',
              );
            }

            final registrosReales = snapshot.data!;
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
                    padding: const EdgeInsets.all(16),
                    itemCount: registros.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final registro = registros[index];

                      return _VitalRecordCard(
                        registro: registro,
                        showPatient: true,
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

class _ScreenError extends StatelessWidget {
  const _ScreenError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _clinicalBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.alertRed,
                size: 40,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: _clinicalTextPrimary,
                ),
              ),
            ],
          ),
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
          borderRadius: BorderRadius.circular(16),
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
                  fontSize: 15,
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

class _RecordDataRow extends StatelessWidget {
  const _RecordDataRow({
    required this.icon,
    required this.text,
    this.iconColor = AppTheme.actionBlue,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              height: 1.35,
              color: _clinicalTextPrimary,
            ),
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
        ? 'Frecuencia cardíaca: No informado'
        : 'Frecuencia cardíaca: ${registro['frecuencia_cardiaca']} bpm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _clinicalBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_note,
                color: _clinicalHeaderBlue,
                size: 30,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPatient)
                      Text(
                        registro['patient'] ?? 'Paciente',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _clinicalTextPrimary,
                        ),
                      ),
                    Text(
                      'Fecha: ${registro['fecha']}',
                      style: TextStyle(
                        fontSize: showPatient ? 16 : 20,
                        fontWeight: showPatient
                            ? FontWeight.w400
                            : FontWeight.w700,
                        color: showPatient
                            ? _clinicalTextSecondary
                            : _clinicalTextPrimary,
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
          const SizedBox(height: AppTheme.spacingMd),
          _RecordDataRow(
            icon: Icons.favorite,
            iconColor: _clinicalAlert,
            text:
                'Presión: ${registro['presion_sistolica']}/${registro['presion_diastolica']} mmHg',
          ),
          const SizedBox(height: AppTheme.spacingSm),
          _RecordDataRow(icon: Icons.monitor_heart, text: frecuenciaTexto),
          if (registro['glucosa'] != null &&
              registro['glucosa'] != 'No informado') ...[
            const SizedBox(height: AppTheme.spacingSm),
            _RecordDataRow(
              icon: Icons.bloodtype,
              iconColor: _clinicalWarning,
              text: 'Glucosa: ${registro['glucosa']} mg/dL',
            ),
          ],
          const SizedBox(height: AppTheme.spacingMd),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacingMd),
          _RecordDataRow(
            icon: Icons.notes,
            iconColor: _clinicalTextSecondary,
            text: 'Observaciones: ${registro['observaciones']}',
          ),
        ],
      ),
    );
  }
}
