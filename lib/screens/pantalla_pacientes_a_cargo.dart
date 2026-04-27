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

// Pantalla simple para listar los pacientes a cargo del cuidador.
class PantallaPacientesACargo extends StatefulWidget {
  const PantallaPacientesACargo({super.key});

  @override
  State<PantallaPacientesACargo> createState() =>
      _PantallaPacientesACargoState();
}

class _PantallaPacientesACargoState extends State<PantallaPacientesACargo> {
  late Future<List<Map<String, String>>> _pacientesFuture;

  @override
  void initState() {
    super.initState();
    // Carga la lista de pacientes al abrir la pantalla.
    _pacientesFuture = _cargarPacientes();
  }

  Future<List<Map<String, String>>> _cargarPacientes() async {
    try {
      // Envia Token real si existe; sin token, la pantalla vuelve a demo.
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return [];
      }

      final response = await http.get(
        Uri.parse(apiCaregiverPatientsUrl),
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

      return items.whereType<Map<String, dynamic>>().map((paciente) {
        final dynamic patientData = paciente['patient'];

        final String patient = patientData is Map<String, dynamic>
            ? patientData['username']?.toString() ??
                  patientData['name']?.toString() ??
                  patientData['id']?.toString() ??
                  'No disponible'
            : patientData?.toString() ?? 'No disponible';
        final String patientLimpio = patient.replaceFirst(
          RegExp(r'^Paciente:\s*'),
          '',
        );

        final String parentesco =
            paciente['parentesco']?.toString() ??
            paciente['relationship']?.toString() ??
            'No disponible';

        final String esPrincipal =
            (paciente['es_principal'] == true || paciente['is_primary'] == true)
            ? 'Sí'
            : 'No';

        return {
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
      }).toList();
    } catch (_) {
      // Si falla la API, no se rompe el flujo demo.
      return [];
    }
  }

  // Lista local de apoyo para mostrar una demo si la API no trae datos.
  List<Map<String, String>> _obtenerPacientesDemo() {
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

  EcronoStatusType _obtenerTipoEstadoPaciente(String estado) {
    final estadoNormalizado = estado.toLowerCase();

    if (estadoNormalizado.contains('estable') ||
        estadoNormalizado.contains('al día') ||
        estadoNormalizado.contains('al dia')) {
      return EcronoStatusType.success;
    }

    if (estadoNormalizado.contains('alerta') ||
        estadoNormalizado.contains('pendiente')) {
      return EcronoStatusType.danger;
    }

    return EcronoStatusType.warning;
  }

  String _obtenerTextoEstadoPaciente(String estado) {
    if (estado == 'No disponible') {
      return 'Revisión';
    }

    return estado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clinicalBackground,
      appBar: AppBar(
        backgroundColor: _clinicalHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text('Pacientes a cargo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, String>>>(
          future: _pacientesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ScreenLoading(
                message: 'Cargando pacientes a cargo...',
              );
            }

            if (snapshot.hasError) {
              return const _ScreenError(
                message: 'No fue posible cargar los pacientes a cargo.',
              );
            }

            final pacientesReales = snapshot.data!;
            final bool usandoDatosDemo = pacientesReales.isEmpty;
            final pacientes = usandoDatosDemo
                ? _obtenerPacientesDemo()
                : pacientesReales;

            return Column(
              children: [
                if (usandoDatosDemo)
                  const _DemoNotice(
                    message:
                        'Mostrando datos demo porque la API no devolvió pacientes asociados.',
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    itemCount: pacientes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppTheme.spacingMd),
                    itemBuilder: (context, index) {
                      final paciente = pacientes[index];
                      final String estadoPaciente =
                          paciente['estado'] ?? 'No disponible';
                      final EcronoStatusType tipoEstado =
                          _obtenerTipoEstadoPaciente(estadoPaciente);

                      return _ClinicalListCard(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: _clinicalHeaderBlue,
                                  size: 32,
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                Expanded(
                                  child: Text(
                                    paciente['patient']!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _clinicalTextPrimary,
                                    ),
                                  ),
                                ),
                                EcronoStatusBadge(
                                  text: _obtenerTextoEstadoPaciente(
                                    estadoPaciente,
                                  ),
                                  status: tipoEstado,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            if (usandoDatosDemo) ...[
                              _RecordDataRow(
                                icon: Icons.cake,
                                text: 'Edad: ${paciente['edad']}',
                              ),
                              const SizedBox(height: AppTheme.spacingSm),
                              _RecordDataRow(
                                icon: Icons.medical_information,
                                text:
                                    'Diagnóstico principal: ${paciente['diagnostico']}',
                              ),
                              const SizedBox(height: AppTheme.spacingSm),
                              _RecordDataRow(
                                icon: Icons.event_available,
                                text:
                                    'Último control: ${paciente['ultimo_control']}',
                              ),
                              const SizedBox(height: AppTheme.spacingSm),
                            ],
                            _RecordDataRow(
                              icon: Icons.family_restroom,
                              text: 'Parentesco: ${paciente['parentesco']}',
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            _RecordDataRow(
                              icon: Icons.verified_user,
                              text:
                                  'Cuidador principal: ${paciente['es_principal']}',
                            ),
                          ],
                        ),
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
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
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
        child: _ClinicalListCard(
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
                  fontSize: 17,
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
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        0,
      ),
      child: _ClinicalListCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: AppTheme.actionBlue),
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
  const _RecordDataRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppTheme.actionBlue),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              color: _clinicalTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClinicalListCard extends StatelessWidget {
  const _ClinicalListCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Se reutiliza la tarjeta e-Crono con borde visible para listas clínicas.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _clinicalBorder),
      ),
      child: EcronoCard(padding: padding, child: child),
    );
  }
}
