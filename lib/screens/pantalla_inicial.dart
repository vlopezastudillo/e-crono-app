import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_routes.dart';
import '../api_constants.dart';
import '../services/biometric_auth_service.dart';
import '../session_helper.dart';

// Pantalla principal de inicio de sesión.
class PantallaInicial extends StatefulWidget {
  const PantallaInicial({super.key});

  @override
  State<PantallaInicial> createState() => _PantallaInicialState();
}

class _PantallaInicialState extends State<PantallaInicial> {
  TextEditingController? _rutController;
  TextEditingController? _passwordController;
  bool _logueando = false;
  bool _autenticandoBiometria = false;
  bool _mostrarIngresoBiometrico = false;

  TextEditingController get _rutInputController =>
      _rutController ??= TextEditingController();
  TextEditingController get _passwordInputController =>
      _passwordController ??= TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializa los campos del login antes del primer build.
    _rutController = TextEditingController();
    _passwordController = TextEditingController();
    _actualizarEstadoBiometria();
  }

  @override
  void dispose() {
    _rutController?.dispose();
    _passwordController?.dispose();
    super.dispose();
  }

  String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  int? _leerEntero(dynamic valor) {
    if (valor == null) {
      return null;
    }
    if (valor is int) {
      return valor;
    }
    if (valor is num) {
      return valor.toInt();
    }
    return int.tryParse(valor.toString());
  }

  void _navegarSegunRol(String role) {
    if (role == 'patient' || role == 'paciente') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.paciente,
        (route) => false,
      );
    } else if (role == 'caregiver' || role == 'cuidador') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.cuidador,
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rol desconocido: $role')));
    }
  }

  Future<void> _actualizarEstadoBiometria() async {
    final bool puedeUsarBiometria =
        await SessionHelper.puedeUsarBiometriaLocal() &&
        await BiometricAuthService.biometriaDisponible();

    if (!mounted) {
      return;
    }

    setState(() {
      _mostrarIngresoBiometrico = puedeUsarBiometria;
    });
  }

  Future<void> _ingresarConBiometria() async {
    if (_autenticandoBiometria) {
      return;
    }

    setState(() {
      _autenticandoBiometria = true;
    });

    final bool puedeUsarBiometria =
        await SessionHelper.puedeUsarBiometriaLocal();
    final bool autenticado = puedeUsarBiometria
        ? await BiometricAuthService.autenticar()
        : false;

    if (!mounted) {
      return;
    }

    setState(() {
      _autenticandoBiometria = false;
    });

    if (!autenticado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo validar la biometría.')),
      );
      return;
    }

    final String? role = (await SessionHelper.obtenerRol())?.toLowerCase();
    if (!mounted) {
      return;
    }

    if (role == null || role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo recuperar la sesión.')),
      );
      return;
    }

    _navegarSegunRol(role);
  }

  Future<void> _ofrecerActivarBiometriaSiCorresponde() async {
    if (await SessionHelper.biometricEnabled()) {
      return;
    }

    final bool disponible = await BiometricAuthService.biometriaDisponible();
    if (!disponible || !mounted) {
      return;
    }

    final bool activar =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Activar ingreso biométrico'),
            content: const Text(
              'Podrás desbloquear e-Crono en este dispositivo usando biometría mientras tu sesión esté activa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Activar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!activar) {
      return;
    }

    final bool autenticado = await BiometricAuthService.autenticar();
    if (autenticado) {
      await SessionHelper.setBiometricEnabled(true);
    }
  }

  Future<bool> _intentarLoginOffline() async {
    final bool haySesion = await SessionHelper.haySesionActiva();
    if (!haySesion) {
      return false;
    }

    final String? role = (await SessionHelper.obtenerRol())?.toLowerCase();
    if (role == null || role.isEmpty) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrando en modo sin conexión')),
    );
    _navegarSegunRol(role);
    return true;
  }

  /// Intenta hacer login real con el backend.
  Future<void> _intentarLogin() async {
    final String identifier = _rutInputController.text.trim();
    final String password = _passwordInputController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu usuario y contraseña')),
      );
      return;
    }

    setState(() {
      _logueando = true;
    });

    try {
      final response = await http.post(
        Uri.parse(apiLoginUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Respuesta de login no valida.');
        }

        final String? token = _leerTexto(data['token']);
        final String? accessToken = _leerTexto(data['access']);
        final String? refreshToken = _leerTexto(data['refresh']);
        final String? username = _leerTexto(data['username']);
        final String? role = _leerTexto(data['role'])?.toLowerCase();
        final int? patientId = _leerEntero(data['patient_id']);

        if ((accessToken != null || token != null) &&
            username != null &&
            role != null) {
          // Guarda la sesion real para usarla en las siguientes llamadas API.
          await SessionHelper.guardarSesion(
            token: token,
            accessToken: accessToken,
            refreshToken: refreshToken,
            username: username,
            role: role,
            patientId: patientId,
          );

          if (!mounted) return;

          await _ofrecerActivarBiometriaSiCorresponde();
          if (!mounted) return;

          // Navegar según el rol
          _navegarSegunRol(role);
          return;
        }
      }

      // Login fallido: se avisa al usuario.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos')),
      );
    } catch (_) {
      final bool entroOffline = await _intentarLoginOffline();
      if (entroOffline) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _logueando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        width: 240,
                        height: 110,
                        child: Image.asset(
                          'assets/images/e-Crono_Logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Accede a tu carnet de salud y controla las próximas atenciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Usuario',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rutInputController,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ingresa tu usuario',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0A2B4E),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Contraseña',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordInputController,
                            obscureText: true,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Contraseña',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                              ),
                              suffixIcon: const Icon(
                                Icons.visibility_off,
                                color: Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0A2B4E),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _logueando ? null : _intentarLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A2B4E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _logueando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                          if (_mostrarIngresoBiometrico) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _autenticandoBiometria
                                    ? null
                                    : _ingresarConBiometria,
                                icon: _autenticandoBiometria
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint),
                                label: const Text('Ingresar con biometría'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0A2B4E),
                                  side: const BorderSide(
                                    color: Color(0xFF0A2B4E),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF3B82F6),
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'e-Crono es tu compañero de salud digital. Tus datos están protegidos y disponibles incluso sin conexión.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
