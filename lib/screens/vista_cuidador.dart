import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_navigation.dart';
import '../api_constants.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';
import 'pantalla_inicial.dart';
import 'pantalla_pacientes_a_cargo.dart';
import 'pantalla_registros_clinicos.dart';

const Color _caregiverBackground = Color(0xFFF3F4F6);
const Color _caregiverHeaderBlue = Color(0xFF0A2B4E);
const Color _caregiverBorder = Color(0xFFE5E7EB);
const Color _caregiverTextPrimary = Color(0xFF111827);
const Color _caregiverTextSecondary = Color(0xFF6B7280);
const Color _caregiverSuccess = Color(0xFF10B981);
const Color _caregiverWarning = Color(0xFFF59E0B);

// Pantalla principal del flujo cuidador.
class VistaCuidador extends StatefulWidget {
  const VistaCuidador({super.key});

  @override
  State<VistaCuidador> createState() => _VistaCuidadorState();
}

class _VistaCuidadorState extends State<VistaCuidador> {
  late Future<List<_PacienteCuidador>> _pacientesFuture;

  @override
  void initState() {
    super.initState();
    // Carga pacientes reales asociados al cuidador al abrir la pantalla.
    _pacientesFuture = _cargarPacientes();
  }

  Future<List<_PacienteCuidador>> _cargarPacientes() async {
    try {
      // Reutiliza el helper para enviar Authorization: Token <token>.
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

      return items.whereType<Map<String, dynamic>>().map((item) {
        return _PacienteCuidador(
          nombre: _limpiarNombrePaciente(item['patient']),
          parentesco: _leerTexto(item['parentesco']) ?? 'No disponible',
          esPrincipal:
              item['es_principal'] == true || item['is_primary'] == true,
        );
      }).toList();
    } catch (_) {
      // Si falla la API, se mantiene la vista demostrativa actual.
      return [];
    }
  }

  String _limpiarNombrePaciente(dynamic valor) {
    final String texto = _leerTexto(valor) ?? 'No disponible';
    return texto.replaceFirst(RegExp(r'^Paciente:\s*'), '');
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

  @override
  Widget build(BuildContext context) {
    return _PantallaDemoRol(
      titulo: 'Seguimiento del cuidador',
      mensajeBienvenida:
          'Revisa a las personas a tu cargo y apoya el seguimiento de sus controles de salud.',
      mensajeDemo:
          'Desde aquí puedes consultar pacientes vinculados, revisar controles recientes y acompañar la continuidad del cuidado.',
      icono: Icons.people,
      textoBotonPrincipal: 'Ver pacientes a cargo',
      textoBotonSecundario: 'Ver registros clínicos',
      pacientesFuture: _pacientesFuture,
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
        // Navega a la lista simple de registros clinicos.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PantallaRegistrosClinicos(),
          ),
        );
      },
    );
  }
}

class _PacienteCuidador {
  const _PacienteCuidador({
    required this.nombre,
    required this.parentesco,
    required this.esPrincipal,
  });

  final String nombre;
  final String parentesco;
  final bool esPrincipal;
}

// Widget reutilizable para una demo simple por rol.
class _PantallaDemoRol extends StatelessWidget {
  const _PantallaDemoRol({
    required this.titulo,
    required this.mensajeBienvenida,
    required this.mensajeDemo,
    required this.icono,
    required this.textoBotonPrincipal,
    required this.textoBotonSecundario,
    this.pacientesFuture,
    this.onCerrarSesion,
    this.onBotonPrincipal,
    this.onBotonSecundario,
  });

  final String titulo;
  final String mensajeBienvenida;
  final String mensajeDemo;
  final IconData icono;
  final String textoBotonPrincipal;
  final String textoBotonSecundario;
  final Future<List<_PacienteCuidador>>? pacientesFuture;
  final VoidCallback? onCerrarSesion;
  final VoidCallback? onBotonPrincipal;
  final VoidCallback? onBotonSecundario;

  void _mostrarMensaje(BuildContext context, String accion) {
    // Muestra un aviso simple para funciones aun no implementadas.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$accion estará disponible pronto en esta demo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _caregiverBackground,
      appBar: AppBar(
        backgroundColor: _caregiverHeaderBlue,
        foregroundColor: Colors.white,
        title: Text(titulo),
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
                  AppTheme.spacingLg,
                  AppTheme.spacingMd,
                  AppTheme.spacingXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, size: 56, color: Colors.white),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      mensajeBienvenida,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CaregiverCard(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: _CaregiverPatientsSummary(
                        pacientesFuture: pacientesFuture,
                        mensajeDemo: mensajeDemo,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    const _CaregiverSectionTitle(
                      title: 'Estado del seguimiento',
                      icon: Icons.health_and_safety,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    const _CaregiverCard(
                      child: Column(
                        children: [
                          _CaregiverStatusItem(
                            icon: Icons.check_circle,
                            title: 'Paciente estable',
                            detail: 'Sin señales de alarma registradas.',
                            statusText: 'Estable',
                            statusType: EcronoStatusType.success,
                          ),
                          Divider(height: AppTheme.spacingLg),
                          _CaregiverStatusItem(
                            icon: Icons.schedule,
                            title: 'Control próximo',
                            detail: 'Revisar continuidad de medicamentos.',
                            statusText: 'Revisión',
                            statusType: EcronoStatusType.warning,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
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
                    const SizedBox(height: AppTheme.spacingSm),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _caregiverHeaderBlue,
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        // Vuelve a la pantalla anterior.
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver'),
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
    // Mantiene la tarjeta del Design System y suma borde clinico del mockup.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _caregiverBorder),
      ),
      child: EcronoCard(padding: padding, child: child),
    );
  }
}

class _CaregiverPatientsSummary extends StatelessWidget {
  const _CaregiverPatientsSummary({
    required this.pacientesFuture,
    required this.mensajeDemo,
  });

  final Future<List<_PacienteCuidador>>? pacientesFuture;
  final String mensajeDemo;

  @override
  Widget build(BuildContext context) {
    final Future<List<_PacienteCuidador>>? future = pacientesFuture;

    if (future == null) {
      return _CaregiverDemoSummary(mensajeDemo: mensajeDemo);
    }

    return FutureBuilder<List<_PacienteCuidador>>(
      future: future,
      builder: (context, snapshot) {
        final List<_PacienteCuidador> pacientes = snapshot.data ?? [];

        if (snapshot.connectionState != ConnectionState.done) {
          return const _CaregiverLoadingSummary();
        }

        if (pacientes.isEmpty) {
          return _CaregiverDemoSummary(mensajeDemo: mensajeDemo);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pacientes vinculados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _caregiverTextPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ...pacientes.expand((paciente) sync* {
              if (paciente != pacientes.first) {
                yield const Divider(height: AppTheme.spacingLg);
              }
              yield _CaregiverPatientRow(paciente: paciente);
            }),
          ],
        );
      },
    );
  }
}

class _CaregiverDemoSummary extends StatelessWidget {
  const _CaregiverDemoSummary({required this.mensajeDemo});

  final String mensajeDemo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vista demostrativa',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _caregiverTextPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          mensajeDemo,
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: _caregiverTextSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        const EcronoStatusBadge(
          text: 'Modo demo',
          status: EcronoStatusType.info,
        ),
      ],
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
            style: TextStyle(fontSize: 16, color: _caregiverTextSecondary),
          ),
        ),
      ],
    );
  }
}

class _CaregiverPatientRow extends StatelessWidget {
  const _CaregiverPatientRow({required this.paciente});

  final _PacienteCuidador paciente;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.person, color: _caregiverHeaderBlue, size: 30),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paciente.nombre,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _caregiverTextPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                'Parentesco: ${paciente.parentesco}',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: _caregiverTextSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              EcronoStatusBadge(
                text: paciente.esPrincipal
                    ? 'Cuidador principal'
                    : 'Cuidador asociado',
                status: paciente.esPrincipal
                    ? EcronoStatusType.success
                    : EcronoStatusType.info,
              ),
            ],
          ),
        ),
      ],
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
        Icon(icon, color: _caregiverHeaderBlue, size: 26),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: _caregiverTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaregiverStatusItem extends StatelessWidget {
  const _CaregiverStatusItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.statusText,
    required this.statusType,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String statusText;
  final EcronoStatusType statusType;

  Color _statusColor(EcronoStatusType statusType) {
    switch (statusType) {
      case EcronoStatusType.success:
        return _caregiverSuccess;
      case EcronoStatusType.warning:
        return _caregiverWarning;
      case EcronoStatusType.danger:
        return AppTheme.alertRed;
      case EcronoStatusType.info:
        return AppTheme.actionBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _statusColor(statusType), size: 30),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _caregiverTextPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: _caregiverTextSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              EcronoStatusBadge(text: statusText, status: statusType),
            ],
          ),
        ),
      ],
    );
  }
}
