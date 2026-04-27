import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Estados visuales simples para comunicar informacion clinica o de sincronizacion.
enum EcronoStatusType { success, warning, danger, info }

// Boton principal para acciones importantes de la app.
class EcronoPrimaryButton extends StatelessWidget {
  const EcronoPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget content = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : _ButtonContent(text: text, icon: icon);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.actionBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.actionBlue.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: content,
      ),
    );
  }
}

// Boton secundario para acciones alternativas o de menor prioridad.
class EcronoSecondaryButton extends StatelessWidget {
  const EcronoSecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.actionBlue,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppTheme.actionBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: _ButtonContent(text: text, icon: icon),
      ),
    );
  }
}

// Tarjeta base para agrupar informacion con buena legibilidad.
class EcronoCard extends StatelessWidget {
  const EcronoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Campo de texto amplio para formularios faciles de leer y tocar.
class EcronoTextField extends StatelessWidget {
  const EcronoTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixText,
  });

  final TextEditingController? controller;
  final String label;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: AppTheme.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
        ),
      ),
    );
  }
}

// Badge para estados rapidos: correcto, pendiente, alerta o informacion.
class EcronoStatusBadge extends StatelessWidget {
  const EcronoStatusBadge({
    super.key,
    required this.text,
    required this.status,
  });

  final String text;
  final EcronoStatusType status;

  @override
  Widget build(BuildContext context) {
    final _StatusStyle style = _statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: style.color),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(EcronoStatusType status) {
    switch (status) {
      case EcronoStatusType.success:
        return const _StatusStyle(
          color: AppTheme.successGreen,
          icon: Icons.check_circle,
        );
      case EcronoStatusType.warning:
        return const _StatusStyle(
          color: AppTheme.pendingOrange,
          icon: Icons.sync_problem,
        );
      case EcronoStatusType.danger:
        return const _StatusStyle(color: AppTheme.alertRed, icon: Icons.error);
      case EcronoStatusType.info:
        return const _StatusStyle(color: AppTheme.actionBlue, icon: Icons.info);
    }
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(text);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppTheme.spacingSm),
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
  }
}

class _StatusStyle {
  const _StatusStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
