# e-Crono

Carnet digital para pacientes con enfermedades cronicas en Atencion Primaria de Salud en Chile.

Aplicacion movil desarrollada en Flutter como parte de un trabajo de titulo de Ingenieria en Computacion e Informatica. Esta orientada a apoyar el seguimiento clinico de pacientes cronicos, especialmente en contextos rurales o con conectividad limitada.

El backend Django se mantiene en un repositorio separado.

---

## Que hace

e-Crono permite a pacientes cronicos y cuidadores acceder a informacion clinica basica, registrar signos vitales y mantener continuidad operativa aun cuando el backend no esta disponible temporalmente.

### Para pacientes

- Inicio de sesion real.
- Vista principal de paciente.
- Visualizacion de registros clinicos propios.
- Registro de signos vitales.
- Recordatorios de medicamentos cuando existen datos disponibles.

### Para cuidadores

- Inicio de sesion real.
- Vista de pacientes vinculados.
- Acceso a pacientes a cargo.
- Registro de signos vitales para pacientes vinculados.
- Visualizacion general de registros clinicos.
- Visualizacion de registros por paciente.

Registros disponibles: presion arterial, frecuencia cardiaca, glucosa y observaciones clinicas.

---

## Estado tecnico actual

- Flutter funcional.
- Backend Django conectado mediante API REST.
- Base de datos PostgreSQL en entorno local del backend.
- Login real contra backend.
- Roles paciente y cuidador implementados en el flujo movil.
- Autenticacion principal con JWT Bearer.
- Refresh token acotado ante respuestas 401.
- Fallback temporal con TokenAuthentication legacy.
- Tokens almacenados con FlutterSecureStorage.
- Datos no sensibles y caches funcionales almacenados con SharedPreferences.
- Modo offline-first para registro de signos vitales.
- Cola local de registros pendientes de sincronizacion.
- Sincronizacion posterior de pendientes.
- Biometria tecnica opcional como desbloqueo local de sesion existente.
- Modo demo desactivado.

No existe integracion real con Hospital Digital, HL7 FHIR ni un portal web clinico en este repositorio.

---

## Stack

| Capa | Tecnologia |
| --- | --- |
| Frontend | Flutter / Dart |
| Backend | Django REST Framework |
| Base de datos backend | PostgreSQL |
| Autenticacion | JWT Bearer con refresh token |
| Almacenamiento seguro | FlutterSecureStorage |
| Cache local | SharedPreferences |

---

## Estructura principal

```text
lib/
├── config/
├── screens/
├── services/
├── theme/
├── widgets/
├── api_constants.dart
├── app_navigation.dart
├── app_routes.dart
├── main.dart
└── session_helper.dart

assets/
android/
ios/
linux/
macos/
windows/
```

---

## Flujo funcional validado

1. Login como cuidador.
2. Visualizacion de pacientes vinculados.
3. Registro online de signos vitales.
4. Visualizacion de registros generales.
5. Visualizacion de registros por paciente.
6. Registro offline con backend apagado.
7. Visualizacion de pendiente de sincronizar.
8. Sincronizacion posterior al recuperar backend.
9. Logout.
10. Nuevo login.

---

## Contexto

El proyecto nace de la necesidad de entregar a pacientes cronicos una forma simple de consultar y registrar informacion relevante para su seguimiento clinico. El objetivo es apoyar continuidad de cuidados en escenarios donde la conectividad puede ser limitada.

---

*Victor Andres Lopez Astudillo — Trabajo de Titulo, 2026*
