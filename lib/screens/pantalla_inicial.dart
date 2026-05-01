import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_routes.dart';
import '../api_constants.dart';
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

      debugPrint('POST login: estado HTTP ${response.statusCode}');
      debugPrint('POST login: respuesta ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Respuesta de login no valida.');
        }

        final String? token = _leerTexto(data['token']);
        final String? username = _leerTexto(data['username']);
        final String? role = _leerTexto(data['role'])?.toLowerCase();
        final int? patientId = _leerEntero(data['patient_id']);

        if (token != null && username != null && role != null) {
          // Guarda la sesion real para usarla en las siguientes llamadas API.
          await SessionHelper.guardarSesion(
            token: token,
            username: username,
            role: role,
            patientId: patientId,
          );

          if (!mounted) return;

          // Navegar según el rol
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
            // Rol desconocido, mostrar error
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Rol desconocido: $role')));
          }
          return;
        }
      }

      // Login fallido: se avisa al usuario.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos')),
      );
    } catch (e) {
      debugPrint('Error en login: $e');
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
