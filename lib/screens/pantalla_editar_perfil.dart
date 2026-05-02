import 'package:flutter/material.dart';

import '../app_navigation.dart';
import '../session_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ecrono_bottom_navigation.dart';
import '../widgets/ecrono_ui.dart';

const Color _profileBackground = Color(0xFFF3F4F6);
const Color _profileHeaderBlue = Color(0xFF0A2B4E);
const Color _profileBorder = Color(0xFFE5E7EB);
const Color _profileTextSecondary = Color(0xFF6B7280);

class PantallaEditarPerfil extends StatefulWidget {
  const PantallaEditarPerfil({super.key});

  @override
  State<PantallaEditarPerfil> createState() => _PantallaEditarPerfilState();
}

class _PantallaEditarPerfilState extends State<PantallaEditarPerfil> {
  static _PerfilLocal _perfilLocal = const _PerfilLocal(
    nombre: 'Sin nombre',
    usuario: 'Sin usuario',
    direccion: 'Sin dirección',
    telefono: 'Sin teléfono',
  );

  late final TextEditingController _nombreController;
  late final TextEditingController _usuarioController;
  late final TextEditingController _direccionController;
  late final TextEditingController _telefonoController;
  late _PerfilLocal _perfilGuardado;

  @override
  void initState() {
    super.initState();
    _perfilGuardado = _perfilLocal;
    _nombreController = TextEditingController(text: _perfilLocal.nombre);
    _usuarioController = TextEditingController(text: _perfilLocal.usuario);
    _direccionController = TextEditingController(text: _perfilLocal.direccion);
    _telefonoController = TextEditingController(text: _perfilLocal.telefono);
    _cargarUsuarioLocal();
  }

  Future<void> _cargarUsuarioLocal() async {
    final String? username = await SessionHelper.getUsername();

    if (!mounted || username == null || username.trim().isEmpty) {
      return;
    }

    if (_usuarioController.text != 'Sin usuario') {
      return;
    }

    setState(() {
      _usuarioController.text = username.trim();
      _perfilGuardado = _perfilGuardado.copyWith(usuario: username.trim());
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _guardarCambios() {
    FocusScope.of(context).unfocus();
    final perfilActualizado = _PerfilLocal(
      nombre: _nombreController.text.trim().isEmpty
          ? 'Sin nombre'
          : _nombreController.text.trim(),
      usuario: _usuarioController.text.trim().isEmpty
          ? 'Sin usuario'
          : _usuarioController.text.trim(),
      direccion: _direccionController.text.trim().isEmpty
          ? 'Sin dirección'
          : _direccionController.text.trim(),
      telefono: _telefonoController.text.trim().isEmpty
          ? 'Sin teléfono'
          : _telefonoController.text.trim(),
    );

    setState(() {
      _perfilLocal = perfilActualizado;
      _perfilGuardado = perfilActualizado;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cambios guardados localmente en este prototipo.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const EcronoBottomSection section = EcronoBottomSection.ajustes;

    return Scaffold(
      backgroundColor: _profileBackground,
      appBar: AppBar(
        backgroundColor: _profileHeaderBlue,
        foregroundColor: Colors.white,
        title: const Text('Editar perfil'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingLg,
            AppTheme.spacingLg,
            AppTheme.spacingLg,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfilePhotoPlaceholder(
                nombre: _perfilGuardado.nombre,
                usuario: _perfilGuardado.usuario,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              const _PrototypeNotice(),
              const SizedBox(height: AppTheme.spacingMd),
              _ProfileLocalSummary(perfil: _perfilGuardado),
              const SizedBox(height: AppTheme.spacingLg),
              _ProfileTextField(
                controller: _nombreController,
                label: 'Nombre',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _ProfileTextField(
                controller: _usuarioController,
                label: 'Usuario',
                icon: Icons.account_circle_outlined,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _ProfileTextField(
                controller: _direccionController,
                label: 'Dirección',
                icon: Icons.home_outlined,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _ProfileTextField(
                controller: _telefonoController,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              EcronoPrimaryButton(
                text: 'Guardar cambios',
                icon: Icons.save_outlined,
                onPressed: _guardarCambios,
              ),
            ],
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

class _PerfilLocal {
  const _PerfilLocal({
    required this.nombre,
    required this.usuario,
    required this.direccion,
    required this.telefono,
  });

  final String nombre;
  final String usuario;
  final String direccion;
  final String telefono;

  _PerfilLocal copyWith({
    String? nombre,
    String? usuario,
    String? direccion,
    String? telefono,
  }) {
    return _PerfilLocal(
      nombre: nombre ?? this.nombre,
      usuario: usuario ?? this.usuario,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
    );
  }
}

class _ProfilePhotoPlaceholder extends StatelessWidget {
  const _ProfilePhotoPlaceholder({required this.nombre, required this.usuario});

  final String nombre;
  final String usuario;

  @override
  Widget build(BuildContext context) {
    return EcronoCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 50),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usuario,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _profileTextSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          const Text(
            'Foto de perfil: carga de imagen disponible próximamente',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _profileTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLocalSummary extends StatelessWidget {
  const _ProfileLocalSummary({required this.perfil});

  final _PerfilLocal perfil;

  @override
  Widget build(BuildContext context) {
    return EcronoCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos locales actuales',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          _ProfileSummaryRow(label: 'Dirección', value: perfil.direccion),
          const SizedBox(height: 6),
          _ProfileSummaryRow(label: 'Teléfono', value: perfil.telefono),
        ],
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: _profileTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Edición local de prototipo. Estos cambios no se envían al sistema todavía.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _profileTextSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _profileBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _profileBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _profileHeaderBlue, width: 1.5),
        ),
      ),
    );
  }
}
