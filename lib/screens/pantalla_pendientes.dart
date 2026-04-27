import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';

const Color _pendingBackground = Color(0xFFF3F4F6);
const Color _pendingHeaderBlue = Color(0xFF0A2B4E);
const Color _pendingBorder = Color(0xFFE5E7EB);

class PantallaPendientes extends StatelessWidget {
  const PantallaPendientes({super.key});

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _pendingBorder),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pending_actions,
                    color: _pendingHeaderBlue,
                    size: 44,
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No tienes pendientes registrados por ahora',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
