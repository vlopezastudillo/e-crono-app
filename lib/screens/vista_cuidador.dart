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
import 'pantalla_agregar_recordatorio_medicamento.dart';
import 'pantalla_inicial.dart';
import 'pantalla_pacientes_a_cargo.dart';

const Color _caregiverBackground = Color(0xFFF3F4F6);
const Color _caregiverHeaderBlue = Color(0xFF0A2B4E);
const Color _caregiverTextSecondary = Color(0xFF6B7280);
const TextStyle _caregiverSectionTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1F2937),
);
const TextStyle _caregiverPatientNameStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1F2937),
  height: 1.18,
);
const TextStyle _caregiverDescriptionStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  height: 1.25,
  color: Color(0xFF6B7280),
);

// Pantalla principal del flujo cuidador.
class VistaCuidador extends StatefulWidget {
  const VistaCuidador({super.key});

  @override
  State<VistaCuidador> createState() => _VistaCuidadorState();
}

class _VistaCuidadorState extends State<VistaCuidador> {
  final PacientesCuidadorService _pacientesService =
      const PacientesCuidadorService();
  final RegistrosClinicosService _registrosService =
      const RegistrosClinicosService();
  final SeguimientoClinicoService _seguimientoService =
      const SeguimientoClinicoService();
  late Future<_CaregiverDashboardData> _dashboardFuture;
  bool _manejandoSesionExpirada = false;

  @override
  void initState() {
    super.initState();
    // Carga pacientes reales asociados al cuidador al abrir la pantalla.
    _dashboardFuture = _cargarDashboardCuidador();
  }

  Future<_CaregiverDashboardData> _cargarDashboardCuidador() async {
    try {
      final results = await Future.wait([
        _pacientesService.cargarPacientesACargo(),
        _registrosService.cargarMisRegistros(),
      ]);
      final List<Map<String, String>> pacientes = results[0];
      final List<Map<String, String>> registros = results[1];
      final bool hayCruce = _seguimientoService.existeCrucePacienteRegistro(
        pacientes,
        registros,
      );
      final SeguimientoClinicoEstado? estadoFallback = _seguimientoService
          .calcularEstado(registros);

      return _CaregiverDashboardData(
        pacientes: pacientes.map((paciente) {
          final List<Map<String, String>> registrosPaciente =
              _seguimientoService.registrosDelPaciente(paciente, registros);
          final SeguimientoClinicoEstado? estado = hayCruce
              ? _seguimientoService.calcularEstado(registrosPaciente)
              : estadoFallback;

          return _PacienteCuidador(
            patientId: _leerPatientIdPaciente(paciente),
            nombre: paciente['patient'] ?? 'No disponible',
            datos: paciente,
            parentesco: paciente['parentesco'] ?? 'No disponible',
            esPrincipal: paciente['es_principal'] == 'Sí',
            estadoClinico: estado,
            usandoFallbackGlobal: !hayCruce && estadoFallback != null,
          );
        }).toList(),
      );
    } on SessionExpiredException catch (error) {
      _manejarSesionExpirada(error);
      return const _CaregiverDashboardData(pacientes: []);
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

  int? _leerPatientId(String? valor) {
    return int.tryParse(valor ?? '');
  }

  int? _leerPatientIdPaciente(Map<String, String> paciente) {
    return _leerPatientId(
      paciente['patient_id'] ??
          paciente['patientId'] ??
          paciente['paciente_id'] ??
          paciente['pacienteId'] ??
          paciente['id'],
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    // Limpia la sesión local y vuelve al inicio sin historial.
    await SessionHelper.clearSession();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaInicial()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PantallaRol(
      titulo: 'Seguimiento del cuidador',
      mensajeBienvenida:
          'Revisa a las personas a tu cargo y apoya el seguimiento de sus controles.',
      icono: Icons.people,
      textoBotonPrincipal: 'Ver pacientes a cargo',
      textoBotonSecundario: 'Registros clínicos',
      dashboardFuture: _dashboardFuture,
      onCerrarSesion: () {
        _cerrarSesion(context);
      },
      onBotonPrincipal: () {
        // Navega a la lista simple de pacientes a cargo.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PantallaPacientesACargo(),
          ),
        );
      },
      onBotonSecundario: () {
        AppNavigation.abrirMisRegistros(context);
      },
    );
  }
}

class _CaregiverDashboardData {
  const _CaregiverDashboardData({required this.pacientes});

  final List<_PacienteCuidador> pacientes;
}

class _PacienteCuidador {
  const _PacienteCuidador({
    required this.patientId,
    required this.nombre,
    required this.datos,
    required this.parentesco,
    required this.esPrincipal,
    required this.estadoClinico,
    required this.usandoFallbackGlobal,
  });

  final int? patientId;
  final String nombre;
  final Map<String, String> datos;
  final String parentesco;
  final bool esPrincipal;
  final SeguimientoClinicoEstado? estadoClinico;
  final bool usandoFallbackGlobal;
}

class _PantallaRol extends StatelessWidget {
  const _PantallaRol({
    required this.titulo,
    required this.mensajeBienvenida,
    required this.icono,
    required this.textoBotonPrincipal,
    required this.textoBotonSecundario,
    this.dashboardFuture,
    this.onCerrarSesion,
    this.onBotonPrincipal,
    this.onBotonSecundario,
  });

  final String titulo;
  final String mensajeBienvenida;
  final IconData icono;
  final String textoBotonPrincipal;
  final String textoBotonSecundario;
  final Future<_CaregiverDashboardData>? dashboardFuture;
  final VoidCallback? onCerrarSesion;
  final VoidCallback? onBotonPrincipal;
  final VoidCallback? onBotonSecundario;

  void _mostrarMensaje(BuildContext context, String accion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$accion estará disponible pronto.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _caregiverBackground,
      appBar: AppBar(
        backgroundColor: _caregiverHeaderBlue,
        foregroundColor: Colors.white,
        title: Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onCerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: _caregiverHeaderBlue,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  10,
                  AppTheme.spacingMd,
                  12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icono, size: 28, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        mensajeBienvenida,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  8,
                  AppTheme.spacingMd,
                  AppTheme.spacingMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CaregiverPatientsSummary(dashboardFuture: dashboardFuture),
                    const SizedBox(height: AppTheme.spacingMd),
                    const _CaregiverSectionTitle(
                      title: 'Acciones rápidas',
                      icon: Icons.touch_app,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    EcronoPrimaryButton(
                      text: textoBotonPrincipal,
                      icon: Icons.list_alt,
                      onPressed: () {
                        if (onBotonPrincipal != null) {
                          onBotonPrincipal!();
                        } else {
                          _mostrarMensaje(context, textoBotonPrincipal);
                        }
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    EcronoSecondaryButton(
                      text: textoBotonSecundario,
                      icon: Icons.description,
                      onPressed: () {
                        if (onBotonSecundario != null) {
                          onBotonSecundario!();
                        } else {
                          _mostrarMensaje(context, textoBotonSecundario);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EcronoBottomNavigation(
        currentSection: EcronoBottomSection.inicio,
        onSectionSelected: (destino) {
          AppNavigation.manejarBarraInferior(
            context,
            actual: EcronoBottomSection.inicio,
            destino: destino,
          );
        },
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({
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

class _CaregiverPatientsSummary extends StatelessWidget {
  const _CaregiverPatientsSummary({required this.dashboardFuture});

  final Future<_CaregiverDashboardData>? dashboardFuture;

  @override
  Widget build(BuildContext context) {
    final Future<_CaregiverDashboardData>? future = dashboardFuture;

    if (future == null) {
      return const _CaregiverCard(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: _CaregiverEmptySummary(),
      );
    }

    return FutureBuilder<_CaregiverDashboardData>(
      future: future,
      builder: (context, snapshot) {
        final List<_PacienteCuidador> pacientes =
            snapshot.data?.pacientes ?? [];

        return _CaregiverPatientsContent(
          pacientes: pacientes,
          isLoading: snapshot.connectionState != ConnectionState.done,
        );
      },
    );
  }
}

class _CaregiverPatientsContent extends StatelessWidget {
  const _CaregiverPatientsContent({
    required this.pacientes,
    required this.isLoading,
  });

  final List<_PacienteCuidador> pacientes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _CaregiverCard(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: _CaregiverLoadingSummary(),
      );
    }

    if (pacientes.isEmpty) {
      return const _CaregiverCard(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: _CaregiverEmptySummary(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CaregiverSectionTitle(
          title: 'Pacientes vinculados',
          icon: Icons.groups,
        ),
        const SizedBox(height: AppTheme.spacingSm),
        ...pacientes.map(
          (paciente) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: _CaregiverPatientCard(paciente: paciente),
          ),
        ),
      ],
    );
  }
}

class _CaregiverEmptySummary extends StatelessWidget {
  const _CaregiverEmptySummary();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No hay datos disponibles',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: _caregiverTextSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CaregiverLoadingSummary extends StatelessWidget {
  const _CaregiverLoadingSummary();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Text(
            'Cargando pacientes vinculados...',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: _caregiverTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaregiverPatientCard extends StatelessWidget {
  const _CaregiverPatientCard({required this.paciente});

  final _PacienteCuidador paciente;

  String _estadoTexto() {
    final SeguimientoClinicoEstado? estado = paciente.estadoClinico;

    if (estado == null) {
      return 'Sin registros';
    }

    switch (estado.nivel) {
      case SeguimientoClinicoNivel.alDia:
        return 'Estable';
      case SeguimientoClinicoNivel.atencion:
        return 'Revisión';
      case SeguimientoClinicoNivel.atrasado:
        return 'Alerta';
    }
  }

  EcronoStatusType _estadoTipo() {
    final SeguimientoClinicoEstado? estado = paciente.estadoClinico;

    if (estado == null) {
      return EcronoStatusType.info;
    }

    switch (estado.nivel) {
      case SeguimientoClinicoNivel.alDia:
        return EcronoStatusType.success;
      case SeguimientoClinicoNivel.atencion:
        return EcronoStatusType.warning;
      case SeguimientoClinicoNivel.atrasado:
        return EcronoStatusType.danger;
    }
  }

  IconData _estadoIcono() {
    final SeguimientoClinicoEstado? estado = paciente.estadoClinico;

    if (estado == null) {
      return Icons.event_busy;
    }

    switch (estado.nivel) {
      case SeguimientoClinicoNivel.alDia:
        return Icons.check_circle;
      case SeguimientoClinicoNivel.atencion:
        return Icons.warning_amber;
      case SeguimientoClinicoNivel.atrasado:
        return Icons.error;
    }
  }

  Color _estadoColor() {
    final SeguimientoClinicoEstado? estado = paciente.estadoClinico;

    if (estado == null) {
      return _caregiverHeaderBlue;
    }

    switch (estado.nivel) {
      case SeguimientoClinicoNivel.alDia:
        return AppTheme.successGreen;
      case SeguimientoClinicoNivel.atencion:
        return AppTheme.pendingOrange;
      case SeguimientoClinicoNivel.atrasado:
        return AppTheme.alertRed;
    }
  }

  void _registrarControl(BuildContext context) {
    final int? patientId = paciente.patientId;

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar el paciente para registrar el control.',
          ),
        ),
      );
      return;
    }

    AppNavigation.abrirSalud(
      context,
      patientId: patientId,
      patientName: paciente.nombre,
    );
  }

  void _verRegistros(BuildContext context) {
    final int? patientId = paciente.patientId;

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar el paciente para ver registros.',
          ),
        ),
      );
      return;
    }

    final String patientName =
        paciente.datos['nombre'] ?? paciente.datos['name'] ?? paciente.nombre;

    AppNavigation.abrirRegistrosPaciente(
      context,
      patientId: patientId,
      patientName: patientName,
    );
  }

  void _agregarRecordatorioMedicamento(BuildContext context) {
    final int? patientId = paciente.patientId;

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar el paciente para crear el recordatorio.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAgregarRecordatorioMedicamento(
          patientId: patientId,
          patientName: paciente.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SeguimientoClinicoEstado? estado = paciente.estadoClinico;
    final String ultimoRegistroTexto = estado == null
        ? 'Sin registros'
        : 'Último registro: hace ${estado.diasDesdeUltimoRegistro} días';

    return EcronoCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _estadoColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(_estadoIcono(), color: _estadoColor(), size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            paciente.nombre,
                            style: _caregiverPatientNameStyle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        EcronoStatusBadge(
                          text: _estadoTexto(),
                          status: _estadoTipo(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ultimoRegistroTexto,
                      style: _caregiverDescriptionStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Parentesco: ${paciente.parentesco}',
                      style: _caregiverDescriptionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (paciente.usandoFallbackGlobal) ...[
            const SizedBox(height: 4),
            const Text(
              'Estado basado en registros disponibles.',
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: _caregiverTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _CaregiverActionButtons(
            onRegistrarControl: () => _registrarControl(context),
            onAbrirRegistros: () => _verRegistros(context),
            onAgregarMedicamento: () =>
                _agregarRecordatorioMedicamento(context),
          ),
        ],
      ),
    );
  }
}

class _CaregiverActionButtons extends StatelessWidget {
  const _CaregiverActionButtons({
    required this.onRegistrarControl,
    required this.onAbrirRegistros,
    required this.onAgregarMedicamento,
  });

  final VoidCallback onRegistrarControl;
  final VoidCallback onAbrirRegistros;
  final VoidCallback onAgregarMedicamento;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool usarColumna = constraints.maxWidth < 330;
        final registrar = _CaregiverActionButton(
          label: 'Registrar',
          icon: Icons.add,
          onPressed: onRegistrarControl,
          isPrimary: true,
        );
        final registros = _CaregiverActionButton(
          label: 'Ver registros',
          icon: Icons.description_outlined,
          onPressed: onAbrirRegistros,
        );
        final medicamento = _CaregiverActionButton(
          label: 'Medicamento',
          icon: Icons.medication_outlined,
          onPressed: onAgregarMedicamento,
        );

        if (usarColumna) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              registrar,
              const SizedBox(height: 6),
              registros,
              const SizedBox(height: 6),
              medicamento,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: registrar),
            const SizedBox(width: 6),
            Expanded(child: registros),
            const SizedBox(width: 6),
            Expanded(child: medicamento),
          ],
        );
      },
    );
  }
}

class _CaregiverActionButton extends StatelessWidget {
  const _CaregiverActionButton({
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
        children: [Icon(icon, size: 15), const SizedBox(width: 4), Text(label)],
      ),
    );

    if (isPrimary) {
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _caregiverHeaderBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _caregiverHeaderBlue,
          side: BorderSide(color: Colors.grey.shade300),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: child,
      ),
    );
  }
}

class _CaregiverSectionTitle extends StatelessWidget {
  const _CaregiverSectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _caregiverHeaderBlue, size: 23),
        const SizedBox(width: 6),
        Expanded(child: Text(title, style: _caregiverSectionTitleStyle)),
      ],
    );
  }
}
