import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ecrono_ui.dart';

class DetalleRegistroClinico extends StatelessWidget {
  const DetalleRegistroClinico({super.key, required this.registro});

  final Map<String, String> registro;

  @override
  Widget build(BuildContext context) {
    final RegistroClinicoEstado estado = RegistroClinicoSemaforoHelper.calcular(
      registro,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBlue,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Detalle del registro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            EcronoCard(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.headerBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppTheme.headerBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombrePaciente(),
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingXs),
                            Text(
                              registro['fecha'] ?? 'No disponible',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      EcronoStatusBadge(
                        text: estado.texto,
                        status: estado.status,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    estado.detalle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            EcronoCard(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.favorite,
                    label: 'Presión arterial',
                    value: _presionArterialTexto(),
                    iconColor: AppTheme.alertRed,
                    iconBackground: const Color(0xFFFEF2F2),
                  ),
                  const Divider(height: AppTheme.spacingLg),
                  _DetailRow(
                    icon: Icons.monitor_heart,
                    label: 'Frecuencia cardíaca',
                    value: _valorConUnidad('frecuencia_cardiaca', 'bpm'),
                    iconColor: AppTheme.headerBlue,
                    iconBackground: const Color(0xFFEFF6FF),
                  ),
                  const Divider(height: AppTheme.spacingLg),
                  _DetailRow(
                    icon: Icons.bloodtype,
                    label: 'Glucosa',
                    value: _valorConUnidad('glucosa', 'mg/dL'),
                    iconColor: AppTheme.pendingOrange,
                    iconBackground: const Color(0xFFFFFBEB),
                  ),
                  const Divider(height: AppTheme.spacingLg),
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Registrado por',
                    value: _valor('registrado_por'),
                    iconColor: AppTheme.textSecondary,
                    iconBackground: const Color(0xFFF3F4F6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            EcronoCard(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Observaciones',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    registro['observaciones'] ?? 'Sin observaciones',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const EcronoCard(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Text(
                'Estos rangos son referenciales para demo y no constituyen diagnóstico médico.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _valor(String key) {
    final String valor = registro[key]?.trim() ?? '';

    if (valor.isEmpty || valor == 'No informado') {
      return 'No disponible';
    }

    return valor;
  }

  String _valorConUnidad(String key, String unidad) {
    final String valor = _valor(key);
    return valor == 'No disponible' ? valor : '$valor $unidad';
  }

  String _presionArterialTexto() {
    final String sistolica = _valor('presion_sistolica');
    final String diastolica = _valor('presion_diastolica');

    if (sistolica == 'No disponible' || diastolica == 'No disponible') {
      return 'No disponible';
    }

    return '$sistolica/$diastolica mmHg';
  }

  String _nombrePaciente() {
    final String patient = registro['patient']?.trim() ?? '';
    final String sinPrefijo = patient.replaceFirst(
      RegExp(r'^Paciente:\s*', caseSensitive: false),
      '',
    );
    final String limpio = sinPrefijo.trim();
    return limpio.isEmpty ? 'Paciente no disponible' : limpio;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum RegistroClinicoSemaforo { estable, atencion, alerta, sinDato }

class RegistroClinicoEstado {
  const RegistroClinicoEstado({
    required this.semaforo,
    required this.texto,
    required this.status,
    required this.detalle,
  });

  final RegistroClinicoSemaforo semaforo;
  final String texto;
  final EcronoStatusType status;
  final String detalle;
}

class RegistroClinicoSemaforoHelper {
  const RegistroClinicoSemaforoHelper._();

  static RegistroClinicoEstado calcular(Map<String, String> registro) {
    final List<RegistroClinicoSemaforo> resultados = [
      evaluarPresionArterial(registro),
      evaluarFrecuenciaCardiaca(registro),
      evaluarGlucosa(registro),
    ];

    if (resultados.contains(RegistroClinicoSemaforo.alerta)) {
      return const RegistroClinicoEstado(
        semaforo: RegistroClinicoSemaforo.alerta,
        texto: 'Alerta',
        status: EcronoStatusType.danger,
        detalle:
            'Hay valores claramente fuera del rango referencial y conviene revisarlos.',
      );
    }

    if (resultados.contains(RegistroClinicoSemaforo.atencion)) {
      return const RegistroClinicoEstado(
        semaforo: RegistroClinicoSemaforo.atencion,
        texto: 'Atención',
        status: EcronoStatusType.warning,
        detalle:
            'Hay valores faltantes o levemente fuera del rango referencial.',
      );
    }

    if (resultados.contains(RegistroClinicoSemaforo.sinDato)) {
      return const RegistroClinicoEstado(
        semaforo: RegistroClinicoSemaforo.atencion,
        texto: 'Atención',
        status: EcronoStatusType.warning,
        detalle:
            'Hay valores faltantes o levemente fuera del rango referencial.',
      );
    }

    return const RegistroClinicoEstado(
      semaforo: RegistroClinicoSemaforo.estable,
      texto: 'Estable',
      status: EcronoStatusType.success,
      detalle: 'Los valores disponibles están dentro del rango referencial.',
    );
  }

  static RegistroClinicoSemaforo evaluarPresionArterial(
    Map<String, String> registro,
  ) {
    final List<RegistroClinicoSemaforo> resultados = [
      _evaluarSistolica(_leerNumero(registro['presion_sistolica'])),
      _evaluarDiastolica(_leerNumero(registro['presion_diastolica'])),
    ];

    if (resultados.contains(RegistroClinicoSemaforo.alerta)) {
      return RegistroClinicoSemaforo.alerta;
    }

    if (resultados.contains(RegistroClinicoSemaforo.atencion)) {
      return RegistroClinicoSemaforo.atencion;
    }

    if (resultados.contains(RegistroClinicoSemaforo.sinDato)) {
      return RegistroClinicoSemaforo.sinDato;
    }

    return RegistroClinicoSemaforo.estable;
  }

  static RegistroClinicoSemaforo evaluarFrecuenciaCardiaca(
    Map<String, String> registro,
  ) {
    return _evaluarFrecuencia(_leerNumero(registro['frecuencia_cardiaca']));
  }

  static RegistroClinicoSemaforo evaluarGlucosa(Map<String, String> registro) {
    return _evaluarGlucosa(_leerNumero(registro['glucosa']));
  }

  static int? _leerNumero(String? valor) {
    final String texto = valor?.trim() ?? '';
    if (texto.isEmpty || texto == 'No informado' || texto == 'No disponible') {
      return null;
    }

    return int.tryParse(texto.split(RegExp(r'\s+')).first);
  }

  static RegistroClinicoSemaforo _evaluarSistolica(int? valor) {
    if (valor == null) {
      return RegistroClinicoSemaforo.sinDato;
    }

    if (valor >= 160 || valor < 80) {
      return RegistroClinicoSemaforo.alerta;
    }

    if ((valor >= 140 && valor <= 159) || (valor >= 80 && valor <= 89)) {
      return RegistroClinicoSemaforo.atencion;
    }

    return RegistroClinicoSemaforo.estable;
  }

  static RegistroClinicoSemaforo _evaluarDiastolica(int? valor) {
    if (valor == null) {
      return RegistroClinicoSemaforo.sinDato;
    }

    if (valor >= 100 || valor < 50) {
      return RegistroClinicoSemaforo.alerta;
    }

    if ((valor >= 90 && valor <= 99) || (valor >= 50 && valor <= 59)) {
      return RegistroClinicoSemaforo.atencion;
    }

    return RegistroClinicoSemaforo.estable;
  }

  static RegistroClinicoSemaforo _evaluarFrecuencia(int? valor) {
    if (valor == null) {
      return RegistroClinicoSemaforo.sinDato;
    }

    if (valor < 50 || valor > 120) {
      return RegistroClinicoSemaforo.alerta;
    }

    if ((valor >= 50 && valor <= 59) || (valor >= 101 && valor <= 120)) {
      return RegistroClinicoSemaforo.atencion;
    }

    return RegistroClinicoSemaforo.estable;
  }

  static RegistroClinicoSemaforo _evaluarGlucosa(int? valor) {
    if (valor == null) {
      return RegistroClinicoSemaforo.sinDato;
    }

    if (valor < 60 || valor > 180) {
      return RegistroClinicoSemaforo.alerta;
    }

    if ((valor >= 60 && valor <= 69) || (valor >= 141 && valor <= 180)) {
      return RegistroClinicoSemaforo.atencion;
    }

    return RegistroClinicoSemaforo.estable;
  }
}
