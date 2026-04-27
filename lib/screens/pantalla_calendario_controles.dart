import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const Color _calendarBackground = Color(0xFFF3F4F6);
const Color _calendarHeaderBlue = Color(0xFF0A2B4E);
const Color _calendarBorder = Color(0xFFE5E7EB);
const Color _calendarTextSecondary = Color(0xFF6B7280);

class PantallaCalendarioControles extends StatelessWidget {
  const PantallaCalendarioControles({super.key});

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
                border: Border.all(color: _calendarBorder),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: _calendarHeaderBlue,
                    size: 44,
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Calendario de controles médicos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'Aquí se visualizarán los próximos controles agendados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _calendarTextSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
