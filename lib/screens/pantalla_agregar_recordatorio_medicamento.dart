import 'package:flutter/material.dart';

import '../services/medication_reminders_service.dart';
import '../services/pacientes_cuidador_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';

const Color _medicationBackground = Color(0xFFF3F4F6);
const Color _medicationHeaderBlue = Color(0xFF0A2B4E);
const Color _medicationTextSecondary = Color(0xFF6B7280);
const List<String> _frequencyOptions = [
  'Diaria',
  'Cada 8 horas',
  'Cada 12 horas',
  'Semanal',
  'Lunes a viernes',
];

class PantallaAgregarRecordatorioMedicamento extends StatefulWidget {
  const PantallaAgregarRecordatorioMedicamento({
    super.key,
    this.patientId,
    this.patientName,
  });

  final int? patientId;
  final String? patientName;

  @override
  State<PantallaAgregarRecordatorioMedicamento> createState() =>
      _PantallaAgregarRecordatorioMedicamentoState();
}

class _PantallaAgregarRecordatorioMedicamentoState
    extends State<PantallaAgregarRecordatorioMedicamento> {
  final MedicationRemindersService _recordatoriosService =
      const MedicationRemindersService();
  final PacientesCuidadorService _pacientesService =
      const PacientesCuidadorService();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  late final Future<List<Map<String, String>>> _pacientesFuture;
  int? _selectedPatientId;
  String? _selectedHour;
  String? _selectedMinute;
  String? _selectedPeriod;
  String? _selectedFrequency;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _pacientesFuture = _pacientesService.cargarPacientesACargo();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _dosisController.dispose();
    super.dispose();
  }

  Future<void> _guardarRecordatorio() async {
    final int? patientId = widget.patientId ?? _selectedPatientId;
    final String nombre = _nombreController.text.trim();
    final String dosis = _dosisController.text.trim();
    final String? frecuencia = _selectedFrequency;

    if (patientId == null) {
      _mostrarMensaje('Selecciona un paciente antes de guardar.');
      return;
    }

    if (nombre.isEmpty) {
      _mostrarMensaje('Ingresa el nombre del medicamento.');
      return;
    }

    if (dosis.isEmpty) {
      _mostrarMensaje('Ingresa la dosis del medicamento.');
      return;
    }

    if (_selectedHour == null) {
      _mostrarMensaje('Selecciona la hora del recordatorio.');
      return;
    }

    if (_selectedMinute == null) {
      _mostrarMensaje('Selecciona los minutos del recordatorio.');
      return;
    }

    if (_selectedPeriod == null) {
      _mostrarMensaje('Selecciona AM o PM.');
      return;
    }

    if (frecuencia == null || frecuencia.isEmpty) {
      _mostrarMensaje('Selecciona la frecuencia del recordatorio.');
      return;
    }

    final String hora = _convertirHora24(
      hour: _selectedHour!,
      minute: _selectedMinute!,
      period: _selectedPeriod!,
    );

    setState(() {
      _guardando = true;
    });

    try {
      await _recordatoriosService.createMedicationReminder(
        patientId: patientId,
        nombre: nombre,
        dosis: dosis,
        hora: hora,
        frecuencia: frecuencia,
      );

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Recordatorio creado correctamente')),
      );
    } on MedicationReminderCreateException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _guardando = false;
      });
      _mostrarMensaje(error.message);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String _convertirHora24({
    required String hour,
    required String minute,
    required String period,
  }) {
    int hour24 = int.parse(hour);

    if (period == 'AM' && hour24 == 12) {
      hour24 = 0;
    } else if (period == 'PM' && hour24 != 12) {
      hour24 += 12;
    }

    final String formattedHour = hour24.toString().padLeft(2, '0');

    return '$formattedHour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _medicationBackground,
      appBar: AppBar(
        backgroundColor: _medicationHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text(
          'Nuevo recordatorio',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PatientTargetSection(
                fixedPatientId: widget.patientId,
                fixedPatientName: widget.patientName,
                pacientesFuture: _pacientesFuture,
                selectedPatientId: _selectedPatientId,
                onPatientSelected: (patient) {
                  setState(() {
                    _selectedPatientId = patient?.id;
                  });
                },
              ),
              const SizedBox(height: AppTheme.spacingSm),
              EcronoCard(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EcronoTextField(
                      controller: _nombreController,
                      label: 'Nombre medicamento',
                      hint: 'Ej: nombre del medicamento',
                      icon: Icons.medication_outlined,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    EcronoTextField(
                      controller: _dosisController,
                      label: 'Dosis',
                      hint: 'Ej: 10 mg',
                      icon: Icons.science_outlined,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    _MedicationTimeSelector(
                      hour: _selectedHour,
                      minute: _selectedMinute,
                      period: _selectedPeriod,
                      onHourChanged: (value) {
                        setState(() {
                          _selectedHour = value;
                        });
                      },
                      onMinuteChanged: (value) {
                        setState(() {
                          _selectedMinute = value;
                        });
                      },
                      onPeriodChanged: (value) {
                        setState(() {
                          _selectedPeriod = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    _FrequencySelectorField(
                      value: _selectedFrequency,
                      onChanged: (value) {
                        setState(() {
                          _selectedFrequency = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              EcronoPrimaryButton(
                text: 'Guardar recordatorio',
                icon: Icons.save_alt,
                isLoading: _guardando,
                onPressed: _guardarRecordatorio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientTargetSection extends StatelessWidget {
  const _PatientTargetSection({
    required this.fixedPatientId,
    required this.fixedPatientName,
    required this.pacientesFuture,
    required this.selectedPatientId,
    required this.onPatientSelected,
  });

  final int? fixedPatientId;
  final String? fixedPatientName;
  final Future<List<Map<String, String>>> pacientesFuture;
  final int? selectedPatientId;
  final ValueChanged<_PatientOption?> onPatientSelected;

  @override
  Widget build(BuildContext context) {
    if (fixedPatientId != null) {
      final String nombre = fixedPatientName?.trim().isNotEmpty == true
          ? fixedPatientName!.trim()
          : 'Paciente seleccionado';

      return EcronoCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.person, color: _medicationHeaderBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recordatorio para: $nombre',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, String>>>(
      future: pacientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const EcronoCard(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cargando pacientes...',
                    style: TextStyle(color: _medicationTextSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        final List<_PatientOption> patientOptions =
            (snapshot.data ?? <Map<String, String>>[])
                .map(_PatientOption.fromMap)
                .whereType<_PatientOption>()
                .toList();

        if (patientOptions.isEmpty) {
          return const EcronoCard(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: _medicationHeaderBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No se encontraron pacientes disponibles.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final Set<int> availableIds = patientOptions
            .map((patient) => patient.id)
            .toSet();
        final int? dropdownValue = availableIds.contains(selectedPatientId)
            ? selectedPatientId
            : null;

        return EcronoCard(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<int>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Paciente',
              prefixIcon: const Icon(
                Icons.person,
                color: _medicationHeaderBlue,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: const BorderSide(color: AppTheme.borderGray),
              ),
            ),
            hint: const Text('Selecciona un paciente'),
            items: patientOptions.map((patient) {
              return DropdownMenuItem<int>(
                value: patient.id,
                child: Text(patient.name),
              );
            }).toList(),
            onChanged: (patientId) {
              _PatientOption? selectedPatient;

              for (final patient in patientOptions) {
                if (patient.id == patientId) {
                  selectedPatient = patient;
                  break;
                }
              }

              onPatientSelected(selectedPatient);
            },
          ),
        );
      },
    );
  }
}

class _MedicationTimeSelector extends StatelessWidget {
  const _MedicationTimeSelector({
    required this.hour,
    required this.minute,
    required this.period,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onPeriodChanged,
  });

  final String? hour;
  final String? minute;
  final String? period;
  final ValueChanged<String?> onHourChanged;
  final ValueChanged<String?> onMinuteChanged;
  final ValueChanged<String?> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> hours = List<String>.generate(
      12,
      (index) => (index + 1).toString().padLeft(2, '0'),
    );
    final List<String> minutes = List<String>.generate(
      12,
      (index) => (index * 5).toString().padLeft(2, '0'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule, color: _medicationHeaderBlue, size: 18),
            SizedBox(width: 8),
            Text(
              'Hora',
              style: TextStyle(
                color: _medicationHeaderBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool usarFila = constraints.maxWidth >= 330;
            final List<Widget> fields = [
              _CompactDropdownField(
                label: 'Hora',
                value: hour,
                items: hours,
                onChanged: onHourChanged,
              ),
              _CompactDropdownField(
                label: 'Min',
                value: minute,
                items: minutes,
                onChanged: onMinuteChanged,
              ),
              _CompactDropdownField(
                label: 'AM/PM',
                value: period,
                items: const ['AM', 'PM'],
                onChanged: onPeriodChanged,
              ),
            ];

            if (!usarFila) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fields[0],
                  const SizedBox(height: 8),
                  fields[1],
                  const SizedBox(height: 8),
                  fields[2],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 8),
                Expanded(child: fields[1]),
                const SizedBox(width: 8),
                Expanded(child: fields[2]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FrequencySelectorField extends StatelessWidget {
  const _FrequencySelectorField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Frecuencia',
        prefixIcon: const Icon(Icons.repeat, color: _medicationTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.borderGray),
        ),
      ),
      hint: const Text('Selecciona frecuencia'),
      items: _frequencyOptions.map((frequency) {
        return DropdownMenuItem<String>(
          value: frequency,
          child: Text(frequency),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _CompactDropdownField extends StatelessWidget {
  const _CompactDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(
            color: _medicationHeaderBlue,
            width: 1.5,
          ),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _PatientOption {
  const _PatientOption({required this.id, required this.name});

  final int id;
  final String name;

  static _PatientOption? fromMap(Map<String, String> patient) {
    final int? id = int.tryParse(patient['patient_id'] ?? '');
    final String name = patient['patient'] ?? 'Paciente';

    if (id == null) {
      return null;
    }

    return _PatientOption(id: id, name: name);
  }
}
