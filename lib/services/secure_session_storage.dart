import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureSessionStorage {
  const SecureSessionStorage._();

  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _legacyTokenKey = 'auth_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> guardarTokens({
    String? accessToken,
    String? refreshToken,
    String? legacyToken,
  }) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.write(key: _accessTokenKey, value: accessToken);
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }

    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _storage.write(key: _legacyTokenKey, value: legacyToken);
    } else if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.delete(key: _legacyTokenKey);
    }

    await _eliminarTokenLegacy();
  }

  static Future<String?> obtenerAccessToken() async {
    return _leerTokenSeguro(_accessTokenKey);
  }

  static Future<String?> obtenerRefreshToken() async {
    return _leerTokenSeguro(_refreshTokenKey);
  }

  static Future<String?> obtenerLegacyToken() async {
    final String? legacySeguro = await _leerTokenSeguro(_legacyTokenKey);
    return legacySeguro ?? _migrarTokenLegacySiExiste();
  }

  static Future<void> guardarAccessToken(String accessToken) async {
    if (accessToken.isEmpty) {
      return;
    }

    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  static Future<void> eliminarTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacyTokenKey);
    await _eliminarTokenLegacy();
  }

  static Future<String?> _leerTokenSeguro(String key) async {
    final String? token = await _storage.read(key: key);
    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  static Future<String?> _migrarTokenLegacySiExiste() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tokenLegacy = prefs.getString(_legacyTokenKey);
    if (tokenLegacy == null || tokenLegacy.isEmpty) {
      return null;
    }

    await _storage.write(key: _legacyTokenKey, value: tokenLegacy);
    await prefs.remove(_legacyTokenKey);
    return tokenLegacy;
  }

  static Future<void> _eliminarTokenLegacy() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokenKey);
  }
}
