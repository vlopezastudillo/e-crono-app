import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  const BiometricAuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> dispositivoSoportaBiometria() async {
    try {
      return _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> biometriaDisponible() async {
    try {
      final bool soporta = await _auth.isDeviceSupported();
      final bool puedeRevisar = await _auth.canCheckBiometrics;
      final List<BiometricType> disponibles = await _auth
          .getAvailableBiometrics();
      return soporta && puedeRevisar && disponibles.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> autenticar() async {
    try {
      final bool disponible = await biometriaDisponible();
      if (!disponible) {
        return false;
      }

      return _auth.authenticate(
        localizedReason: 'Confirma tu identidad para ingresar a e-Crono.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
