import 'package:flutter/foundation.dart';

// URL base del backend local segun la plataforma donde corre Flutter.
// No usamos dart:io porque rompe compatibilidad con Flutter Web.
String get apiBaseUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // En Android Emulator, 10.0.2.2 apunta al localhost del Mac.
      return 'http://10.0.2.2:8000';
    case TargetPlatform.iOS:
      // En iOS Simulator, 127.0.0.1 apunta al localhost del Mac.
      return 'http://127.0.0.1:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

String get apiMeUrl => '$apiBaseUrl/api/me/';
String get apiCaregiverPatientsUrl => '$apiBaseUrl/api/caregiver-patients/';
String get apiVitalSignRecordsUrl => '$apiBaseUrl/api/vital-sign-records/';

// URL para login en el backend
String get apiLoginUrl => '$apiBaseUrl/api/login/';
