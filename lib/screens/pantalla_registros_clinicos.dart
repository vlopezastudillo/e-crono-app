import 'dart:convert';

import 'package:flutter/material.dart';

import '../api_constants.dart';
import '../session_expired_handler.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';

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
  bool _manejandoSesionExpirada = false;

  @override
  void initState() {
    super.initState();
    // Carga la lista de registros al abrir la pantalla.
    _registrosFuture = _cargarRegistros();
  }

  Future<List<Map<String, String>>> _cargarRegistros() async {
    try {
      // Envia Authorization cuando hay login real guardado.
      final response = await SessionHelper.authenticatedGet(
        Uri.parse(apiVitalSignRecordsUrl),
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
    } on SessionExpiredException catch (error) {
      _manejarSesionExpirada(error);
      return [];
    } catch (_) {
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
            final registros = registrosReales;

            return Column(
              children: [
                Expanded(
                  child: registros.isEmpty
                      ? const _EmptyRecordsState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: registros.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final registro = registros[index];

                            return _VitalRecordCard(
                              registro: registro,
                              showPatient: true,
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

class _EmptyRecordsState extends StatelessWidget {
  const _EmptyRecordsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Text(
          'No hay datos disponibles',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: _clinicalTextSecondary,
            fontWeight: FontWeight.w700,
          ),
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
  const _VitalRecordCard({required this.registro, this.showPatient = true});

  final Map<String, String> registro;
  final bool showPatient;

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
