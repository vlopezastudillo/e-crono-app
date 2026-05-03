import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../services/pacientes_cuidador_service.dart';
import '../services/registros_clinicos_service.dart';
import '../services/seguimiento_clinico_service.dart';
import '../session_expired_handler.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';

const Color _pendingBackground = Color(0xFFF3F4F6);
const Color _pendingHeaderBlue = Color(0xFF0A2B4E);
const Color _pendingTextPrimary = Color(0xFF111827);
const Color _pendingTextSecondary = Color(0xFF6B7280);

class PantallaPendientes extends StatefulWidget {
  const PantallaPendientes({super.key});

  @override
  State<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends State<PantallaPendientes> {
  final RegistrosClinicosService _registrosService =
      const RegistrosClinicosService();
  final PacientesCuidadorService _pacientesService =
      const PacientesCuidadorService();
  final SeguimientoClinicoService _seguimientoService =
      const SeguimientoClinicoService();
  late Future<_PendientesData> _pendientesFuture;
  bool _manejandoSesionExpirada = false;

  @override
  void initState() {
    super.initState();
    _pendientesFuture = _cargarPendientes();
  }

  Future<_PendientesData> _cargarPendientes() async {
    try {
      final String? role = await SessionHelper.getRole();
      final bool esCuidador = _esRolCuidador(role);

      if (esCuidador) {
        final results = await Future.wait([
          _pacientesService.cargarPacientesACargo(),
          _registrosService.cargarMisRegistros(),
        ]);

        return _PendientesData.cuidador(
          pacientes: results[0],
          registros: results[1],
        );
      }

      final List<Map<String, String>> registros = await _registrosService
          .cargarMisRegistros();

      return _PendientesData.paciente(registros: registros);
    } on SessionExpiredException catch (error) {
      _manejarSesionExpirada(error);
      return const _PendientesData.paciente(registros: []);
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

  bool _esRolCuidador(String? role) {
    final String roleNormalizado = role?.toLowerCase().trim() ?? '';
    return roleNormalizado == 'caregiver' || roleNormalizado == 'cuidador';
  }

  _PatientPendingStatus? _calcularEstadoPaciente(
    List<Map<String, String>> registros,
  ) {
    final SeguimientoClinicoEstado? estado = _seguimientoService.calcularEstado(
      registros,
    );

    if (estado == null) {
      return null;
    }

    switch (estado.nivel) {
      case SeguimientoClinicoNivel.alDia:
        return _PatientPendingStatus(
          daysSinceLastRecord: estado.diasDesdeUltimoRegistro,
          label: 'Al día',
          status: EcronoStatusType.success,
          color: AppTheme.successGreen,
          icon: Icons.check_circle,
        );
      case SeguimientoClinicoNivel.atencion:
        return _PatientPendingStatus(
          daysSinceLastRecord: estado.diasDesdeUltimoRegistro,
          label: 'Atención',
          status: EcronoStatusType.warning,
          color: AppTheme.pendingOrange,
          icon: Icons.warning_amber,
        );
      case SeguimientoClinicoNivel.atrasado:
        return _PatientPendingStatus(
          daysSinceLastRecord: estado.diasDesdeUltimoRegistro,
          label: 'Atrasado',
          status: EcronoStatusType.danger,
          color: AppTheme.alertRed,
          icon: Icons.error,
        );
    }
  }

  bool _hayCrucePacienteRegistro(
    List<Map<String, String>> pacientes,
    List<Map<String, String>> registros,
  ) {
    return _seguimientoService.existeCrucePacienteRegistro(
      pacientes,
      registros,
    );
  }

  bool _pacienteTieneRegistroCruzado(
    Map<String, String> paciente,
    List<Map<String, String>> registros,
  ) {
    return _seguimientoService
        .registrosDelPaciente(paciente, registros)
        .isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    const EcronoBottomSection section = EcronoBottomSection.pendientes;

    return Scaffold(
      backgroundColor: _pendingBackground,
      appBar: AppBar(
        backgroundColor: _pendingHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text('Pendientes'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<_PendientesData>(
          future: _pendientesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _PendingLoading();
            }

            final _PendientesData data =
                snapshot.data ?? const _PendientesData.paciente(registros: []);

            return data.esCuidador
                ? _CaregiverPendingView(
                    pacientes: data.pacientes,
                    registros: data.registros,
                    hasCrossedRecords: _hayCrucePacienteRegistro(
                      data.pacientes,
                      data.registros,
                    ),
                    patientHasCrossedRecord: (paciente) =>
                        _pacienteTieneRegistroCruzado(paciente, data.registros),
                  )
                : _PatientPendingView(
                    status: _calcularEstadoPaciente(data.registros),
                  );
          },
        ),
      ),
      bottomNavigationBar: EcronoBottomNavigation(
        currentSection: section,
        onSectionSelected: (destino) {
          AppNavigation.manejarBarraInferior(
            context,
            actual: section,
            destino: destino,
          );
        },
      ),
    );
  }
}

class _PendientesData {
  const _PendientesData.paciente({required this.registros})
    : esCuidador = false,
      pacientes = const [];

  const _PendientesData.cuidador({
    required this.pacientes,
    required this.registros,
  }) : esCuidador = true;

  final bool esCuidador;
  final List<Map<String, String>> pacientes;
  final List<Map<String, String>> registros;
}

class _PatientPendingStatus {
  const _PatientPendingStatus({
    required this.daysSinceLastRecord,
    required this.label,
    required this.status,
    required this.color,
    required this.icon,
  });

  final int daysSinceLastRecord;
  final String label;
  final EcronoStatusType status;
  final Color color;
  final IconData icon;
}

class _PendingLoading extends StatelessWidget {
  const _PendingLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingMd),
            Text(
              'Revisando pendientes...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _pendingTextSecondary,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientPendingView extends StatelessWidget {
  const _PatientPendingView({required this.status});

  final _PatientPendingStatus? status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        _SectionHeader(
          icon: Icons.monitor_heart,
          title: 'Seguimiento de registros clínicos',
          subtitle: 'Estado según el último registro disponible.',
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (status == null)
          const _EmptyStateCard(
            icon: Icons.event_busy,
            title: 'No tienes registros aún',
            subtitle: 'Cuando exista un registro clínico, aparecerá aquí.',
          )
        else
          EcronoCard(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusIcon(color: status!.color, icon: status!.icon),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Último registro: hace ${status!.daysSinceLastRecord} días',
                            style: const TextStyle(
                              color: _pendingTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          const Text(
                            'Mantén tu historial actualizado para facilitar el seguimiento.',
                            style: TextStyle(
                              color: _pendingTextSecondary,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                EcronoStatusBadge(text: status!.label, status: status!.status),
              ],
            ),
          ),
      ],
    );
  }
}

class _CaregiverPendingView extends StatelessWidget {
  const _CaregiverPendingView({
    required this.pacientes,
    required this.registros,
    required this.hasCrossedRecords,
    required this.patientHasCrossedRecord,
  });

  final List<Map<String, String>> pacientes;
  final List<Map<String, String>> registros;
  final bool hasCrossedRecords;
  final bool Function(Map<String, String> paciente) patientHasCrossedRecord;

  @override
  Widget build(BuildContext context) {
    if (pacientes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: const [
          _SectionHeader(
            icon: Icons.groups,
            title: 'Pacientes a cargo',
            subtitle: 'Estado general de seguimiento clínico.',
          ),
          SizedBox(height: AppTheme.spacingMd),
          _EmptyStateCard(
            icon: Icons.person_off,
            title: 'No hay pacientes asociados',
            subtitle: 'Cuando existan pacientes a cargo, aparecerán aquí.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: pacientes.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _SectionHeader(
            icon: Icons.groups,
            title: 'Pacientes a cargo',
            subtitle: 'Indicador simple según registros clínicos disponibles.',
          );
        }

        final Map<String, String> paciente = pacientes[index - 1];
        final bool tieneRegistros = hasCrossedRecords
            ? patientHasCrossedRecord(paciente)
            : registros.isNotEmpty;

        return _CaregiverPatientCard(
          patientName: paciente['patient'] ?? 'Paciente',
          hasRecords: tieneRegistros,
          usingGlobalFallback: !hasCrossedRecords && registros.isNotEmpty,
        );
      },
    );
  }
}

class _CaregiverPatientCard extends StatelessWidget {
  const _CaregiverPatientCard({
    required this.patientName,
    required this.hasRecords,
    required this.usingGlobalFallback,
  });

  final String patientName;
  final bool hasRecords;
  final bool usingGlobalFallback;

  @override
  Widget build(BuildContext context) {
    final EcronoStatusType status = hasRecords
        ? EcronoStatusType.success
        : EcronoStatusType.danger;
    final Color color = hasRecords ? AppTheme.successGreen : AppTheme.alertRed;
    final String statusText = hasRecords
        ? 'Tiene registros'
        : 'No tiene registros recientes';

    return EcronoCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusIcon(
            color: color,
            icon: hasRecords ? Icons.check_circle : Icons.error,
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    color: _pendingTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (usingGlobalFallback) ...[
                  const SizedBox(height: AppTheme.spacingXs),
                  const Text(
                    'Estado basado en existencia general de registros.',
                    style: TextStyle(
                      color: _pendingTextSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingSm),
                EcronoStatusBadge(text: statusText, status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return EcronoCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: _pendingHeaderBlue, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _pendingTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _pendingTextSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return EcronoCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          Icon(icon, color: _pendingHeaderBlue, size: 42),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pendingTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pendingTextSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
