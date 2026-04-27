# e-Crono 📱  
Carnet digital para pacientes con enfermedades crónicas en APS Chile  

Aplicación móvil en Flutter, trabajo de título de Ingeniería en Computación e Informática. Está orientada a mejorar el seguimiento clínico en Atención Primaria de Salud, especialmente en contextos rurales o con conectividad limitada.

> Versión demo funcional — datos simulados, backend no incluido en este repositorio.

---

## ¿Qué hace?

e-Crono permite a pacientes crónicos y sus cuidadores acceder a un registro clínico digital simple, sin depender de conectividad constante.

### Para el paciente
- Visualización de información personal y registros clínicos  
- Interfaz orientada a adultos mayores (legible, fácil de usar)

### Para el cuidador / TENS
- Vista de pacientes a cargo con acceso a información clínica relevante  

Registros disponibles: presión arterial, frecuencia cardíaca, glucosa y observaciones clínicas.

---

## Stack

| Capa           | Tecnología                 |
|----------------|--------------------------|
| Frontend       | Flutter (Dart)           |
| Backend        | Django REST Framework    |
| Base de datos  | PostgreSQL               |

La arquitectura está diseñada como **offline-first**: pensada para funcionar en zonas con conectividad limitada o intermitente.

---

## Estado actual

- [x] Aplicación Flutter funcional  
- [x] Integración con endpoint /api/me/  
- [ ] Integración completa con backend  
- [ ] Datos reales (actualmente simulados)  

El backend está desarrollado pero **no incluido en este repositorio** por razones de alcance del proyecto y separación de componentes.

---

## Estructura

```text
lib/
├── screens/
├── widgets/
└── main.dart
assets/
android/
ios/
```

---

## Contexto

Este proyecto nació de una necesidad real: los pacientes crónicos en Chile, especialmente adultos mayores en zonas rurales, no cuentan con una forma simple de llevar su historial clínico consigo. e-Crono apunta a ser esa solución, con miras a integrarse en el futuro con sistemas de salud pública, cumpliendo normativas chilenas de protección de datos.

---

*Víctor Andrés López Astudillo — Trabajo de Título, 2026*
