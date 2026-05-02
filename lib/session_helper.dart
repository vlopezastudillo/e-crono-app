import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_constants.dart';
import 'services/secure_session_storage.dart';

/// Helper simple para guardar y recuperar la sesión del usuario.
/// Usa almacenamiento seguro para el token y SharedPreferences para datos no sensibles.
class SessionHelper {
  // Claves para SharedPreferences
  static const String _keyUsername = 'username';
  static const String _keyRole = 'role';
  static const String _keyPatientId = 'patient_id';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyPacientesCuidadorOffline =
      'pacientes_cuidador_offline';
  static const String _keyRegistrosClinicosOffline =
      'registros_clinicos_vinculados_offline';

  /// Guarda los datos de sesión del usuario después de un login exitoso.
  static Future<bool> guardarSesion({
    String? token,
    String? accessToken,
    String? refreshToken,
    required String username,
    required String role,
    int? patientId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await SecureSessionStorage.guardarTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        legacyToken: token,
      );
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
      if (patientId != null) {
        await prefs.setInt(_keyPatientId, patientId);
      } else {
        // Si el usuario es cuidador, limpiamos cualquier paciente previo.
        await prefs.remove(_keyPatientId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Recupera el token de autenticación.
  static Future<String?> getToken() async {
    return SecureSessionStorage.obtenerAccessToken();
  }

  static Future<String?> obtenerToken() {
    return getToken();
  }

  static Future<String?> getRefreshToken() {
    return SecureSessionStorage.obtenerRefreshToken();
  }

  static Future<String?> getLegacyToken() {
    return SecureSessionStorage.obtenerLegacyToken();
  }

  /// Recupera el nombre de usuario.
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<String?> obtenerUsuario() {
    return getUsername();
  }

  /// Recupera el rol del usuario (patient o caregiver).
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<String?> obtenerRol() {
    return getRole();
  }

  /// Recupera el ID del paciente asociado (null para cuidadores).
  static Future<int?> getPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPatientId);
  }

  static Future<int?> obtenerPatientId() {
    return getPatientId();
  }

  /// Verifica si existe una sesión activa.
  static Future<bool> haySesionActiva() async {
    final accessToken = await getToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      return true;
    }

    final legacyToken = await getLegacyToken();
    return legacyToken != null && legacyToken.isNotEmpty;
  }

  static Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  static Future<bool> puedeUsarBiometriaLocal() async {
    if (!await biometricEnabled()) {
      return false;
    }

    final String? username = await getUsername();
    final String? role = await getRole();
    if (username == null || username.isEmpty || role == null || role.isEmpty) {
      return false;
    }

    final String? accessToken = await getToken();
    final String? refreshToken = await getRefreshToken();
    return (accessToken != null && accessToken.isNotEmpty) ||
        (refreshToken != null && refreshToken.isNotEmpty);
  }

  /// Cierra la sesión eliminando todos los datos guardados.
  static Future<bool> cerrarSesion() async {
    return clearSession();
  }

  /// Limpia token, usuario, rol, paciente y caches de la sesión visible.
  static Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await SecureSessionStorage.eliminarTokens();
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyPatientId);
      await prefs.remove(_keyBiometricEnabled);
      await prefs.remove(_keyPacientesCuidadorOffline);
      await prefs.remove(_keyRegistrosClinicosOffline);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> limpiarSesion() {
    return clearSession();
  }

  /// Obtiene los headers con el token de autorización para llamadas API.
  static Future<Map<String, String>> getAuthHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final accessToken = await getToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
      return headers;
    }

    final legacyToken = await getLegacyToken();
    if (legacyToken != null && legacyToken.isNotEmpty) {
      headers['Authorization'] = 'Token $legacyToken';
    }
    return headers;
  }

  static Future<bool> refrescarAccessToken() async {
    try {
      final String? refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await http.post(
        Uri.parse(apiTokenRefreshUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final dynamic data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return false;
      }

      final String? accessToken = _leerTexto(data['access']);
      if (accessToken == null) {
        return false;
      }

      await SecureSessionStorage.guardarAccessToken(accessToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> authenticatedGet(Uri uri) async {
    final response = await http.get(uri, headers: await getAuthHeaders());
    return _reintentarGetSiNoAutorizado(uri, response);
  }

  static Future<http.Response> authenticatedPost(
    Uri uri, {
    Object? body,
  }) async {
    final response = await http.post(
      uri,
      headers: await getAuthHeaders(),
      body: body,
    );
    return _reintentarPostSiNoAutorizado(uri, response, body: body);
  }

  static Future<http.Response> _reintentarGetSiNoAutorizado(
    Uri uri,
    http.Response response,
  ) async {
    if (response.statusCode != 401 || !await refrescarAccessToken()) {
      return response;
    }

    return http.get(uri, headers: await getAuthHeaders());
  }

  static Future<http.Response> _reintentarPostSiNoAutorizado(
    Uri uri,
    http.Response response, {
    Object? body,
  }) async {
    if (response.statusCode != 401 || !await refrescarAccessToken()) {
      return response;
    }

    return http.post(uri, headers: await getAuthHeaders(), body: body);
  }

  static String? _leerTexto(dynamic valor) {
    final String texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }
}
