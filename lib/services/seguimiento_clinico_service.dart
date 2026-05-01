import 'registros_clinicos_service.dart';

enum SeguimientoClinicoNivel { alDia, atencion, atrasado }

class SeguimientoClinicoEstado {
  const SeguimientoClinicoEstado({
    required this.diasDesdeUltimoRegistro,
    required this.nivel,
  });

  final int diasDesdeUltimoRegistro;
  final SeguimientoClinicoNivel nivel;
}

class SeguimientoClinicoService {
  const SeguimientoClinicoService();

  SeguimientoClinicoEstado? calcularEstado(
    List<Map<String, String>> registros,
  ) {
    final List<DateTime> fechas = registros
        .map(RegistrosClinicosService.leerFechaRegistro)
        .whereType<DateTime>()
        .toList();

    if (fechas.isEmpty) {
      return null;
    }

    fechas.sort((a, b) => b.compareTo(a));
    final DateTime hoy = DateTime.now();
    final DateTime hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final DateTime ultimoSinHora = DateTime(
      fechas.first.year,
      fechas.first.month,
      fechas.first.day,
    );
    final int dias = hoySinHora.difference(ultimoSinHora).inDays;
    final int diasNormalizados = dias < 0 ? 0 : dias;

    if (diasNormalizados <= 1) {
      return SeguimientoClinicoEstado(
        diasDesdeUltimoRegistro: diasNormalizados,
        nivel: SeguimientoClinicoNivel.alDia,
      );
    }

    if (diasNormalizados <= 3) {
      return SeguimientoClinicoEstado(
        diasDesdeUltimoRegistro: diasNormalizados,
        nivel: SeguimientoClinicoNivel.atencion,
      );
    }

    return SeguimientoClinicoEstado(
      diasDesdeUltimoRegistro: diasNormalizados,
      nivel: SeguimientoClinicoNivel.atrasado,
    );
  }

  List<Map<String, String>> registrosDelPaciente(
    Map<String, String> paciente,
    List<Map<String, String>> registros,
  ) {
    final String pacienteId = _normalizarTexto(paciente['patient_id']);
    final String nombrePaciente = _normalizarTexto(paciente['patient']);

    return registros.where((registro) {
      final String registroPatientId = _normalizarTexto(registro['patient_id']);
      final String nombreRegistro = _normalizarTexto(registro['patient']);

      if (pacienteId.isNotEmpty &&
          registroPatientId.isNotEmpty &&
          pacienteId == registroPatientId) {
        return true;
      }

      if (nombrePaciente.isEmpty || nombrePaciente == 'no disponible') {
        return false;
      }

      return nombreRegistro.isNotEmpty &&
          (nombreRegistro.contains(nombrePaciente) ||
              nombrePaciente.contains(nombreRegistro));
    }).toList();
  }

  bool existeCrucePacienteRegistro(
    List<Map<String, String>> pacientes,
    List<Map<String, String>> registros,
  ) {
    return pacientes.any((paciente) {
      return registrosDelPaciente(paciente, registros).isNotEmpty;
    });
  }

  String _normalizarTexto(String? texto) {
    return (texto ?? '')
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
