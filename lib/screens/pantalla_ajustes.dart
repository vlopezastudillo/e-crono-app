import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';

const Color _settingsBackground = Color(0xFFF3F4F6);
const Color _settingsHeaderBlue = Color(0xFF0A2B4E);
const Color _settingsTextSecondary = Color(0xFF6B7280);

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    const EcronoBottomSection section = EcronoBottomSection.ajustes;

    return Scaffold(
      backgroundColor: _settingsBackground,
      appBar: AppBar(
        backgroundColor: _settingsHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text('Ajustes'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          children: [
            _SettingsCard(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              detail: 'Actualiza tus datos personales de forma local.',
              onTap: () => AppNavigation.abrirEditarPerfil(context),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const _SettingsCard(
              icon: Icons.notifications,
              title: 'Notificaciones',
              detail: 'Opciones de recordatorios disponibles próximamente.',
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const _SettingsCard(
              icon: Icons.lock,
              title: 'Privacidad',
              detail: 'Preferencias de seguridad disponibles próximamente.',
            ),
          ],
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: EcronoCard(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _settingsHeaderBlue, size: 26),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: _settingsTextSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppTheme.spacingSm),
              const Icon(
                Icons.chevron_right,
                color: _settingsTextSecondary,
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
