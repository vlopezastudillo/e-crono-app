import 'package:shared_preferences/shared_preferences.dart';

/// Helper simple para guardar y recuperar la sesión del usuario.
/// Utiliza shared_preferences para persistir datos en el dispositivo.
class SessionHelper {
  // Claves para SharedPreferences
  static const String _keyToken = 'auth_token';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'role';
  static const String _keyPatientId = 'patient_id';

  /// Guarda los datos de sesión del usuario después de un login exitoso.
  static Future<bool> guardarSesion({
    required String token,
    required String username,
    required String role,
    int? patientId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// Recupera el nombre de usuario.
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Recupera el rol del usuario (patient o caregiver).
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  /// Recupera el ID del paciente asociado (null para cuidadores).
  static Future<int?> getPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPatientId);
  }

  /// Verifica si existe una sesión activa.
  static Future<bool> haySesionActiva() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Cierra la sesión eliminando todos los datos guardados.
  static Future<bool> cerrarSesion() async {
    return clearSession();
  }

  /// Limpia token, usuario, rol y paciente para cerrar sesión.
  static Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyPatientId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los headers con el token de autorización para llamadas API.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }
}
