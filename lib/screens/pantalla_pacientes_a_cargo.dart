import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../services/pacientes_cuidador_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';

const Color _clinicalBackground = Color(0xFFF3F4F6);
const Color _clinicalHeaderBlue = Color(0xFF0A2B4E);
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
  final PacientesCuidadorService _pacientesService =
      const PacientesCuidadorService();
  late Future<List<Map<String, String>>> _pacientesFuture;

  @override
  void initState() {
    super.initState();
    // Carga la lista de pacientes al abrir la pantalla.
    _pacientesFuture = _pacientesService.cargarPacientesACargo();
  }

  // Lista local de apoyo para mostrar una demo si la API no trae datos.
  List<Map<String, String>> _obtenerPacientesDemo() {
    return _pacientesService.obtenerPacientesDemo();
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
      return 'Atención';
    }

    return estado;
  }

  int? _leerPatientId(Map<String, String> paciente) {
    return int.tryParse(paciente['patient_id'] ?? '');
  }

  String _leerNombrePaciente(Map<String, String> paciente) {
    final String nombre = paciente['patient']?.trim() ?? '';
    return nombre.isEmpty ? 'Paciente seleccionado' : nombre;
  }

  void _registrarControl(BuildContext context, Map<String, String> paciente) {
    final int? patientId = _leerPatientId(paciente);

    if (patientId == null) {
      _mostrarPacienteNoIdentificado(
        context,
        'No se pudo identificar el paciente para registrar el control.',
      );
      return;
    }

    AppNavigation.abrirSalud(
      context,
      patientId: patientId,
      patientName: _leerNombrePaciente(paciente),
    );
  }

  void _verRegistros(BuildContext context, Map<String, String> paciente) {
    final int? patientId = _leerPatientId(paciente);

    if (patientId == null) {
      _mostrarPacienteNoIdentificado(
        context,
        'No se pudo identificar el paciente para ver registros.',
      );
      return;
    }

    AppNavigation.abrirRegistrosPaciente(
      context,
      patientId: patientId,
      patientName: _leerNombrePaciente(paciente),
    );
  }

  void _mostrarPacienteNoIdentificado(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
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
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final paciente = pacientes[index];
                      final String estadoPaciente =
                          paciente['estado'] ?? 'No disponible';
                      final EcronoStatusType tipoEstado =
                          _obtenerTipoEstadoPaciente(estadoPaciente);

                      return _ClinicalListCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: _clinicalHeaderBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: AppTheme.spacingSm),
                                Expanded(
                                  child: Text(
                                    _leerNombrePaciente(paciente),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _clinicalTextPrimary,
                                      height: 1.25,
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
                            const SizedBox(height: AppTheme.spacingSm),
                            if (usandoDatosDemo) ...[
                              _RecordDataRow(
                                icon: Icons.cake,
                                text: 'Edad: ${paciente['edad']}',
                              ),
                              const SizedBox(height: 6),
                              _RecordDataRow(
                                icon: Icons.medical_information,
                                text:
                                    'Diagnóstico principal: ${paciente['diagnostico']}',
                              ),
                              const SizedBox(height: 6),
                              _RecordDataRow(
                                icon: Icons.event_available,
                                text:
                                    'Último control: ${paciente['ultimo_control']}',
                              ),
                              const SizedBox(height: 6),
                            ],
                            _RecordDataRow(
                              icon: Icons.family_restroom,
                              text: 'Parentesco: ${paciente['parentesco']}',
                            ),
                            const SizedBox(height: 6),
                            _RecordDataRow(
                              icon: Icons.verified_user,
                              text:
                                  'Cuidador principal: ${paciente['es_principal']}',
                            ),
                            const SizedBox(height: 10),
                            _PatientCardActions(
                              onRegistrar: () =>
                                  _registrarControl(context, paciente),
                              onVerRegistros: () =>
                                  _verRegistros(context, paciente),
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

class _PatientCardActions extends StatelessWidget {
  const _PatientCardActions({
    required this.onRegistrar,
    required this.onVerRegistros,
  });

  final VoidCallback onRegistrar;
  final VoidCallback onVerRegistros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool usarColumna = constraints.maxWidth < 280;
        final Widget registrar = _CompactPatientButton(
          label: 'Registrar',
          icon: Icons.add,
          onPressed: onRegistrar,
          isPrimary: true,
        );
        final Widget registros = _CompactPatientButton(
          label: 'Ver registros',
          icon: Icons.description_outlined,
          onPressed: onVerRegistros,
        );

        if (usarColumna) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [registrar, const SizedBox(height: 8), registros],
          );
        }

        return Row(
          children: [
            Expanded(child: registrar),
            const SizedBox(width: 8),
            Expanded(child: registros),
          ],
        );
      },
    );
  }
}

class _CompactPatientButton extends StatelessWidget {
  const _CompactPatientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final Widget child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
      ),
    );

    if (isPrimary) {
      return SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _clinicalHeaderBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _clinicalHeaderBlue,
          side: BorderSide(color: Colors.grey.shade300),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: child,
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
                fontSize: 14,
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
                  fontSize: 14,
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
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        0,
      ),
      child: _ClinicalListCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: _clinicalHeaderBlue),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: _clinicalTextSecondary,
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
        Icon(icon, size: 18, color: _clinicalHeaderBlue),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: _clinicalTextSecondary,
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
    return EcronoCard(padding: padding, child: child);
  }
}
