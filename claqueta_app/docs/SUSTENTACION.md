# Guion de sustentación (5 minutos)

**0:00 – Qué es (30 s).** Claqueta: app para realizadores audiovisuales freelance. Cotiza, agenda y cobra desde el celular. El problema: hoy cotizan por WhatsApp y Excel, olvidan hacer seguimiento y se les cruzan los rodajes.

**0:30 – Demo (2 min 30 s), en este orden:**
1. Inicio: próximo rodaje, alertas de seguimiento y de cruces.
2. Cotizar → Nueva: cliente, 3 videos y 10 fotos, descuento, el total se arma solo.
3. Ver PDF → Enviar por WhatsApp.
4. Agenda: agendar dos trabajos cercanos y mostrar el cruce.
5. Registrar un pago y ver cómo cambia Finanzas.

**3:00 – Design System (45 s).** `tema.dart` y `estilo.dart`: paleta, tipografías y componentes en un solo lugar. Cambio el acento en una línea y cambia toda la app. Un acento (arena) para lo importante.

**3:45 – Arquitectura (45 s).** Modelos, una tienda (`ChangeNotifier`) con la lógica, y pantallas que solo dibujan. Prueba de lógica con `flutter test`.

**4:30 – Alcance y honestidad (30 s).** 10 de 12 funcionalidades completas; el clima, el login de Google, el mapa y Calendar están simulados y se conectan en la versión final.

## Preguntas probables

- **¿Por qué `ChangeNotifier` y no Provider/Bloc?** Para la escala del proyecto basta, es lo visto en clase y evita dependencias.
- **¿Dónde se guardan los datos?** En el dispositivo con `SharedPreferences`, como JSON. Hay copia de seguridad.
- **¿Qué es simulado?** Login de Google, clima, mapa y Calendar. Lo demás es real.
- **¿Cómo detecta cruces?** Mismo día y menos de 240 minutos entre horas de inicio (`conflictosPara` en `tienda.dart`).
- **¿Cómo calcula el total?** Subtotal de ítems, menos descuento %, más IVA 19 % si está activo (`Cotizacion` en `modelos.dart`).
