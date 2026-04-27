import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_navigation.dart';
import '../api_constants.dart';
import '../session_helper.dart';
import 'pantalla_inicial.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';

const Color _dashboardBackground = Color(0xFFF3F4F6);
const Color _dashboardHeaderBlue = Color(0xFF0A2B4E);
const Color _dashboardBorder = Color(0xFFE5E7EB);
const Color _dashboardTextSecondary = Color(0xFF6B7280);
const Color _dashboardSuccess = Color(0xFF10B981);
const Color _dashboardAlert = Color(0xFFEF4444);
const Color _dashboardWarning = Color(0xFFF59E0B);
const TextStyle _dashboardTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1F2937),
);
const TextStyle _dashboardPatientNameStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1F2937),
);
const TextStyle _dashboardDescriptionStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  height: 1.35,
  color: Color(0xFF6B7280),
);
const TextStyle _dashboardSmallStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.normal,
  color: Color(0xFF6B7280),
);
const TextStyle _dashboardSmallBoldStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

// Pantalla principal del flujo paciente.
class VistaPaciente extends StatefulWidget {
  const VistaPaciente({super.key});

  @override
  State<VistaPaciente> createState() => _VistaPacienteState();
}

class _VistaPacienteState extends State<VistaPaciente> {
  late Future<_PacienteResumen?> _pacienteFuture;

  @override
  void initState() {
    super.initState();
    // Carga los datos reales del paciente al abrir la pantalla.
    _pacienteFuture = _cargarPaciente();
  }

  Future<_PacienteResumen?> _cargarPaciente() async {
    try {
      // Reutiliza el helper para enviar Authorization: Token <token>.
      final Map<String, String> headers = await SessionHelper.getAuthHeaders();

      if (!headers.containsKey('Authorization')) {
        return null;
      }

      final response = await http.get(Uri.parse(apiMeUrl), headers: headers);

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic data = jsonDecode(response.body);

      if (data is! Map<String, dynamic> || data['patient'] is! Map) {
        return null;
      }

      final Map<String, dynamic> patient = Map<String, dynamic>.from(
        data['patient'] as Map,
      );
      final String? nombre = _leerTexto(patient['nombre']);

      if (nombre == null) {
        return null;
      }

      return _PacienteResumen(
        nombre: nombre,
        rut: _leerTexto(patient['rut']) ?? 'RUT no registrado',
        fechaNacimiento: _leerTexto(patient['fecha_nacimiento']),
        direccion: _leerTexto(patient['direccion']),
        observaciones: _leerTexto(patient['observaciones']),
      );
    } catch (_) {
      // Si falla la API, se mantiene la informacion demo existente.
      return null;
    }
  }

  String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
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

  void _abrirMisRegistros(BuildContext context) {
    // Mantiene la navegacion existente hacia la lista de registros.
    AppNavigation.abrirMisRegistros(context);
  }

  void _abrirRegistroControl(BuildContext context) {
    AppNavigation.abrirSalud(context);
  }

  void _abrirCalendarioControles(BuildContext context) {
    AppNavigation.abrirCalendarioControles(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashboardBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 124,
                width: double.infinity,
                color: _dashboardHeaderBlue,
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 168,
                      height: 66,
                      child: Image.asset(
                        'assets/images/e-Crono_Logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: () {
                        _cerrarSesion(context);
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FutureBuilder<_PacienteResumen?>(
                    future: _pacienteFuture,
                    builder: (context, snapshot) {
                      final _PacienteResumen? paciente = snapshot.data;
                      final bool cargando =
                          snapshot.connectionState != ConnectionState.done;
                      final bool usarDemo = !cargando && paciente == null;

                      return _PacientePrincipalCard(
                        paciente: paciente ?? _PacienteResumen.demo(),
                        cargando: cargando,
                        usarDemo: usarDemo,
                        onAbrirMisRegistros: () => _abrirMisRegistros(context),
                        onRegistrarControl: () =>
                            _abrirRegistroControl(context),
                      );
                    },
                  ),
                ),
              ),
              const _DashboardSectionTitle(
                title: 'Próximos controles médicos',
                icon: Icons.calendar_month,
              ),
              const SizedBox(height: 8),
              _DashboardCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: _ControlItem(
                        title: 'Control médico',
                        detail: 'CESFAM San Vicente',
                        statusText: 'Falta 3 días',
                        statusType: EcronoStatusType.info,
                      ),
                    ),
                    const Divider(height: 1, color: _dashboardBorder),
                    InkWell(
                      onTap: () => _abrirCalendarioControles(context),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: _dashboardHeaderBlue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ver calendario completo',
                              style: TextStyle(
                                color: _dashboardHeaderBlue,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _DashboardSectionTitle(
                title: 'Recordatorio de medicamentos',
                icon: Icons.medication,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const _MedicationItem(
                      name: 'Enalapril 10 mg.',
                      schedule: 'Tomado a las 08:00.',
                      statusText: 'Tomado',
                      statusType: EcronoStatusType.success,
                    ),
                    const SizedBox(height: 12),
                    const _MedicationItem(
                      name: 'Metformina 850 mg.',
                      schedule: 'Pendiente - 13:00 hrs.',
                      statusText: 'TOMAR AHORA',
                      statusType: EcronoStatusType.danger,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '¿No olvide tomar un medicamento de las 13:00 hrs!',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 88),
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

class _PacienteResumen {
  const _PacienteResumen({
    required this.nombre,
    required this.rut,
    this.fechaNacimiento,
    this.direccion,
    this.observaciones,
  });

  final String nombre;
  final String rut;
  final String? fechaNacimiento;
  final String? direccion;
  final String? observaciones;

  // Datos demo originales para casos sin token o con falla de API.
  factory _PacienteResumen.demo() {
    return const _PacienteResumen(
      nombre: 'María Ester Silva',
      rut: '6.372.XXX-X',
    );
  }
}

class _PacientePrincipalCard extends StatelessWidget {
  const _PacientePrincipalCard({
    required this.paciente,
    required this.cargando,
    required this.usarDemo,
    required this.onAbrirMisRegistros,
    required this.onRegistrarControl,
  });

  final _PacienteResumen paciente;
  final bool cargando;
  final bool usarDemo;
  final VoidCallback onAbrirMisRegistros;
  final VoidCallback onRegistrarControl;

  @override
  Widget build(BuildContext context) {
    final String nombre = cargando ? 'Cargando paciente...' : paciente.nombre;
    final List<Widget> datosPaciente = cargando
        ? const [
            _PacienteInfoRow(
              label: '',
              value: 'Obteniendo datos desde /api/me/',
            ),
          ]
        : _crearDatosPaciente();

    return _DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF3B82F6),
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: _dashboardPatientNameStyle),
                    const SizedBox(height: 4),
                    ...datosPaciente,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PatientActionButtons(
            onRegistrarControl: onRegistrarControl,
            onAbrirMisRegistros: onAbrirMisRegistros,
          ),
        ],
      ),
    );
  }

  List<Widget> _crearDatosPaciente() {
    if (usarDemo) {
      return const [
        _PacienteInfoRow(label: '', value: '72 años - RUT: 6.372.XXX-X'),
      ];
    }

    final List<Widget> filas = [
      _PacienteInfoRow(label: 'RUT', value: paciente.rut),
    ];

    if (paciente.fechaNacimiento != null) {
      filas.add(
        _PacienteInfoRow(label: 'Nacimiento', value: paciente.fechaNacimiento!),
      );
    }

    if (paciente.direccion != null) {
      filas.add(
        _PacienteInfoRow(label: 'Dirección', value: paciente.direccion!),
      );
    }

    if (paciente.observaciones != null) {
      filas.add(
        _PacienteInfoRow(
          label: 'Observaciones',
          value: paciente.observaciones!,
        ),
      );
    }

    return filas.expand((fila) sync* {
      if (fila != filas.first) {
        yield const SizedBox(height: 4);
      }
      yield fila;
    }).toList();
  }
}

class _PatientActionButtons extends StatelessWidget {
  const _PatientActionButtons({
    required this.onRegistrarControl,
    required this.onAbrirMisRegistros,
  });

  final VoidCallback onRegistrarControl;
  final VoidCallback onAbrirMisRegistros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool usarColumna = constraints.maxWidth < 330;
        final registrar = _PatientActionButton(
          label: 'Registrar',
          icon: Icons.add,
          onPressed: onRegistrarControl,
          isPrimary: true,
        );
        final registros = _PatientActionButton(
          label: 'Mis registros',
          icon: Icons.description_outlined,
          onPressed: onAbrirMisRegistros,
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

class _PatientActionButton extends StatelessWidget {
  const _PatientActionButton({
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
            backgroundColor: _dashboardHeaderBlue,
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
          foregroundColor: _dashboardHeaderBlue,
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    // Tarjeta base local para lograr la sombra suave del dashboard.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: EcronoCard(padding: padding, child: child),
    );
  }
}

class _PacienteInfoRow extends StatelessWidget {
  const _PacienteInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Text(value, style: _dashboardDescriptionStyle);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              height: 1.35,
              color: _dashboardTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              height: 1.35,
              color: _dashboardTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [Expanded(child: Text(title, style: _dashboardTitleStyle))],
      ),
    );
  }
}

class _ControlItem extends StatelessWidget {
  const _ControlItem({
    required this.title,
    required this.detail,
    required this.statusText,
    required this.statusType,
  });

  final String title;
  final String detail;
  final String statusText;
  final EcronoStatusType statusType;

  Color _statusColor(EcronoStatusType statusType) {
    switch (statusType) {
      case EcronoStatusType.success:
        return _dashboardSuccess;
      case EcronoStatusType.warning:
        return _dashboardWarning;
      case EcronoStatusType.danger:
        return _dashboardAlert;
      case EcronoStatusType.info:
        return const Color(0xFF0284C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Column(
            children: const [
              Text(
                '15',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: 2),
              Text('DIC', style: _dashboardSmallStyle),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(detail, style: _dashboardDescriptionStyle),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.schedule, color: Color(0xFF6B7280), size: 15),
                  SizedBox(width: 4),
                  Text('09:30 hrs.', style: _dashboardSmallStyle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            statusText,
            style: _dashboardSmallBoldStyle.copyWith(
              color: _statusColor(statusType),
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicationItem extends StatelessWidget {
  const _MedicationItem({
    required this.name,
    required this.schedule,
    required this.statusText,
    required this.statusType,
  });

  final String name;
  final String schedule;
  final String statusText;
  final EcronoStatusType statusType;

  bool get _isPending => statusType == EcronoStatusType.danger;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = _isPending
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFDCFCE7);
    final Color borderColor = _isPending
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF86EFAC);
    final Color iconColor = _isPending
        ? const Color(0xFFEF4444)
        : const Color(0xFF16A34A);
    final IconData icon = _isPending ? Icons.error : Icons.check_circle;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(schedule, style: _dashboardDescriptionStyle),
              ],
            ),
          ),
          if (_isPending) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                statusText,
                style: _dashboardSmallBoldStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
