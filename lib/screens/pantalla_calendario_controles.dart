import 'package:flutter/material.dart';

import '../services/registros_clinicos_service.dart';
import '../theme/app_theme.dart';
import 'pantalla_mis_registros.dart';

const Color _calendarBackground = Color(0xFFF3F4F6);
const Color _calendarHeaderBlue = Color(0xFF0A2B4E);
const Color _calendarBorder = Color(0xFFE5E7EB);
const Color _calendarTextPrimary = Color(0xFF111827);
const Color _calendarTextSecondary = Color(0xFF6B7280);
const Color _calendarSoftBlue = Color(0xFFEFF6FF);
const Color _calendarSoftGreen = Color(0xFFECFDF5);

const List<String> _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> _weekdayNames = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

class PantallaCalendarioControles extends StatefulWidget {
  const PantallaCalendarioControles({super.key});

  @override
  State<PantallaCalendarioControles> createState() =>
      _PantallaCalendarioControlesState();
}

class _PantallaCalendarioControlesState
    extends State<PantallaCalendarioControles> {
  final RegistrosClinicosService _registrosService =
      const RegistrosClinicosService();
  late Future<List<Map<String, String>>> _registrosFuture;
  late DateTime _mesVisible;

  @override
  void initState() {
    super.initState();
    final DateTime hoy = DateTime.now();
    _mesVisible = DateTime(hoy.year, hoy.month);
    _registrosFuture = _registrosService.cargarMisRegistros();
  }

  void _irAlMesAnterior() {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month - 1);
    });
  }

  void _irAlMesSiguiente() {
    setState(() {
      _mesVisible = DateTime(_mesVisible.year, _mesVisible.month + 1);
    });
  }

  void _mostrarMensajeSinRegistros() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No hay registros clínicos en este día.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _abrirRegistrosDelDia(
    DateTime fecha,
    List<Map<String, String>> registros,
  ) {
    final List<Map<String, String>> registrosDelDia = _filtrarRegistrosDelDia(
      fecha,
      registros,
    );

    if (registrosDelDia.isEmpty) {
      _mostrarMensajeSinRegistros();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaMisRegistros(
          registrosFiltrados: registrosDelDia,
          fechaFiltrada: fecha,
        ),
      ),
    );
  }

  List<Map<String, String>> _filtrarRegistrosDelDia(
    DateTime fechaSeleccionada,
    List<Map<String, String>> registros,
  ) {
    return registros.where((registro) {
      final DateTime? fechaRegistro =
          RegistrosClinicosService.leerFechaRegistro(registro);

      if (fechaRegistro == null) {
        return false;
      }

      return _mismoDia(fechaRegistro, fechaSeleccionada);
    }).toList();
  }

  Map<DateTime, int> _agruparRegistrosPorDia(
    List<Map<String, String>> registros,
  ) {
    final Map<DateTime, int> registrosPorDia = {};

    for (final registro in registros) {
      final DateTime? fecha = RegistrosClinicosService.leerFechaRegistro(
        registro,
      );

      if (fecha == null) {
        continue;
      }

      final DateTime dia = DateTime(fecha.year, fecha.month, fecha.day);
      registrosPorDia[dia] = (registrosPorDia[dia] ?? 0) + 1;
    }

    return registrosPorDia;
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _calendarBackground,
      appBar: AppBar(
        backgroundColor: _calendarHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text('Calendario'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, String>>>(
          future: _registrosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _CalendarLoading();
            }

            final List<Map<String, String>> registrosReales = snapshot.hasError
                ? <Map<String, String>>[]
                : snapshot.data ?? <Map<String, String>>[];
            final List<Map<String, String>> registros = registrosReales;
            final Map<DateTime, int> registrosPorDia = _agruparRegistrosPorDia(
              registros,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CalendarMonthCard(
                        mesVisible: _mesVisible,
                        registrosPorDia: registrosPorDia,
                        onPreviousMonth: _irAlMesAnterior,
                        onNextMonth: _irAlMesSiguiente,
                        onDayTap: (fecha) =>
                            _abrirRegistrosDelDia(fecha, registros),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading();

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
              'Cargando calendario...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _calendarTextSecondary,
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

class _CalendarMonthCard extends StatelessWidget {
  const _CalendarMonthCard({
    required this.mesVisible,
    required this.registrosPorDia,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final DateTime mesVisible;
  final Map<DateTime, int> registrosPorDia;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final DateTime primerDiaDelMes = DateTime(
      mesVisible.year,
      mesVisible.month,
    );
    final int espaciosIniciales = primerDiaDelMes.weekday - 1;
    final int diasDelMes = DateTime(
      mesVisible.year,
      mesVisible.month + 1,
      0,
    ).day;
    final int totalCeldas = ((espaciosIniciales + diasDelMes + 6) ~/ 7) * 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _calendarBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MonthNavButton(
                icon: Icons.chevron_left,
                tooltip: 'Mes anterior',
                onPressed: onPreviousMonth,
              ),
              Expanded(
                child: Text(
                  _nombreMes(mesVisible),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _calendarTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              _MonthNavButton(
                icon: Icons.chevron_right,
                tooltip: 'Mes siguiente',
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: _weekdayNames
                .map((weekday) => Expanded(child: _WeekdayLabel(weekday)))
                .toList(),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          GridView.builder(
            itemCount: totalCeldas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final int numeroDia = index - espaciosIniciales + 1;

              if (numeroDia < 1 || numeroDia > diasDelMes) {
                return const SizedBox.shrink();
              }

              final DateTime fecha = DateTime(
                mesVisible.year,
                mesVisible.month,
                numeroDia,
              );
              final int cantidadRegistros = registrosPorDia[fecha] ?? 0;

              return _CalendarDayCell(
                dayNumber: numeroDia,
                hasRecords: cantidadRegistros > 0,
                isToday: _mismoDia(fecha, DateTime.now()),
                onTap: () => onDayTap(fecha),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _nombreMes(DateTime fecha) {
    return '${_monthNames[fecha.month - 1]} ${fecha.year}';
  }

  static bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: _calendarHeaderBlue,
      style: IconButton.styleFrom(
        backgroundColor: _calendarSoftBlue,
        fixedSize: const Size(42, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          color: _calendarTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.dayNumber,
    required this.hasRecords,
    required this.isToday,
    required this.onTap,
  });

  final int dayNumber;
  final bool hasRecords;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isToday
        ? AppTheme.actionBlue
        : hasRecords
        ? _calendarSoftGreen
        : Colors.white;
    final Color borderColor = isToday
        ? AppTheme.actionBlue
        : hasRecords
        ? AppTheme.successGreen.withValues(alpha: 0.36)
        : _calendarBorder;
    final Color textColor = isToday ? Colors.white : _calendarTextPrimary;
    final Color markerColor = isToday ? Colors.white : AppTheme.successGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: hasRecords ? markerColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
