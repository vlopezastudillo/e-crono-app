import 'package:flutter/material.dart';

enum EcronoBottomSection { inicio, salud, pendientes, ajustes }

const Color _bottomNavActive = Color(0xFF0A2B4E);
const Color _bottomNavInactive = Color(0xFF9CA3AF);
const Color _bottomNavBorder = Color(0xFFE5E7EB);

class EcronoBottomNavigation extends StatelessWidget {
  const EcronoBottomNavigation({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
  });

  final EcronoBottomSection currentSection;
  final ValueChanged<EcronoBottomSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _bottomNavBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _EcronoBottomItem(
              icon: Icons.home,
              label: 'Inicio',
              section: EcronoBottomSection.inicio,
              isActive: currentSection == EcronoBottomSection.inicio,
              onTap: onSectionSelected,
            ),
            _EcronoBottomItem(
              icon: Icons.favorite,
              label: 'Salud',
              section: EcronoBottomSection.salud,
              isActive: currentSection == EcronoBottomSection.salud,
              onTap: onSectionSelected,
            ),
            _EcronoBottomItem(
              icon: Icons.pending_actions,
              label: 'Pendientes',
              section: EcronoBottomSection.pendientes,
              isActive: currentSection == EcronoBottomSection.pendientes,
              onTap: onSectionSelected,
            ),
            _EcronoBottomItem(
              icon: Icons.settings,
              label: 'Ajustes',
              section: EcronoBottomSection.ajustes,
              isActive: currentSection == EcronoBottomSection.ajustes,
              onTap: onSectionSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _EcronoBottomItem extends StatelessWidget {
  const _EcronoBottomItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final EcronoBottomSection section;
  final bool isActive;
  final ValueChanged<EcronoBottomSection> onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? _bottomNavActive : _bottomNavInactive;

    return InkWell(
      onTap: () => onTap(section),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
