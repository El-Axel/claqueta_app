# Guion de sustentación (≈ 10 minutos)

**Idea que debe quedar:** Claqueta resuelve el día a día de un realizador freelance
(cotizar, agendar, cobrar) y conecta al cliente en la misma app, con integraciones reales,
datos en la nube y seguridad explicable.

**Dos roles en vivo:**

| Rol | Dispositivo | Cómo entra |
|---|---|---|
| Realizador | Emulador Android (o celular) | "Soy realizador · Continuar con Google" |
| Cliente | Celular del profesor o navegador del PC | "Soy cliente · tengo un código" + código `CLQ-XXXXXX` |

> Si la versión web en Netlify ya está publicada, el profesor puede abrirla en su celular.
> Si no, el rol cliente se muestra en Chrome del PC (`flutter run -d chrome --dart-define-from-file=dart_defines.json`).

## Guion paso a paso

| Min | Qué hago | Qué digo |
|---|---|---|
| 0:00 | Pantalla de entrada | "Claqueta es para realizadores audiovisuales freelance. Hoy cotizan por WhatsApp y Excel, olvidan el seguimiento y se les cruzan los rodajes. La app tiene dos puertas: realizador y cliente." |
| 0:40 | Entrar con Google (realizador) | "Pide solo dos permisos: enviar correo y crear eventos. No puede leer mi bandeja. La app está en modo Prueba de Google, por eso sale el aviso de app no verificada." |
| 1:20 | **Inicio** | "De un vistazo: próximo rodaje con clima real, alertas de seguimiento, cruces y lo que me mandan los clientes en *Requiere tu atención*." |
| 2:00 | **Cotizar → Nueva**: cliente, 3 videos y 10 fotos, descuento | "Los precios viven en el catálogo; yo solo anoto lo que pide el cliente y el total se arma solo: subtotal, menos descuento, más IVA si aplica." |
| 3:00 | **Ver PDF → Enviar por Gmail** | "El correo sale desde mi Gmail, con la identidad de mi portafolio en HTML y el PDF adjunto." (Mostrar el correo recibido en el celular o en Gmail.) La cotización queda *Enviada*. |
| 4:00 | Ficha del cliente → **código** `CLQ-…` | "Cada cliente tiene un código. Se lo mando por WhatsApp. No necesita cuenta ni correo." |
| 4:30 | **Rol cliente**: escribir el código | "Entra como usuario anónimo y la base de datos solo le deja ver lo suyo. No ve mis borradores ni a otros clientes." |
| 5:15 | Cliente → Cotizaciones → **Aceptar** | "El cliente no cambia mis datos: deja una respuesta. Mi app revisa la bandeja cada minuto." |
| 5:45 | Cliente → **Solicitar** (tipo, fecha, lugar) | "También puede pedirme una cotización nueva." |
| 6:15 | Volver al realizador (esperar ≤ 1 min o reabrir Inicio) | "La cotización pasó sola a *Aceptada* y la solicitud apareció en *Requiere tu atención*." |
| 6:45 | **Agendar trabajo** desde la aceptada: escribir una dirección | "Busca con OpenStreetMap priorizando mi ciudad. Mapa real, clima real de Open-Meteo hasta 16 días; más lejos dice *Estimado*. Si hay cruce o lluvia, propone plan B. *Cómo llegar* abre Google Maps." |
| 7:45 | Guardar con evento en Calendar | Mostrar el evento en Google Calendar. "Y al cliente le llega una novedad en su app." |
| 8:15 | Registrar un pago → **Finanzas** | "Todo se calcula desde cotizaciones y pagos: cobrado, por cobrar, tasa de aceptación." |
| 8:45 | **Ajustes → Nube "Al día"** | "Cada cambio se copia a Supabase 2 s después. Probamos desinstalar y reinstalar: al entrar con Google ofrece *Traerlos a este teléfono*. Sin internet sigue funcionando." |
| 9:15 | Design System y arquitectura (código) | "`tema.dart` y `estilo.dart`: un solo acento arena y componentes compartidos. Capas: pantallas → tienda → servicios → APIs. 16 pruebas automáticas, una toca 180 elementos sin errores." |
| 9:45 | Cierre | "13 de 13 funcionalidades completas. Pendiente: probar el APK en un celular real y algunos flujos de Calendar." |

**Si algo falla en vivo:** decirlo con calma y mostrar la evidencia (correo ya recibido,
evento en el calendario, `docs/PRUEBA_CLICS.md`). La app sigue funcionando sin red.

## Preguntas probables del jurado

| Pregunta | Respuesta corta |
|---|---|
| ¿Por qué OpenStreetMap y no Google Maps? | Google Maps exige activar facturación con tarjeta. OSM y Open-Meteo son gratis, sin clave y sin secretos en la app. Para la ruta uso un enlace a Google Maps, que no pide clave. |
| ¿Dónde están las claves? | En `dart_defines.json`, fuera de git, y se pasan al compilar con `--dart-define-from-file`. No uso Client Secret porque una app móvil no puede guardar secretos. |
| La clave de Supabase está en la app, ¿no es inseguro? | Es la clave *anon*, pública a propósito. La seguridad la pone la base de datos con RLS: cada fila tiene dueño y la regla "solo lo mío" impide ver datos ajenos. La `service_role` nunca va en la app. |
| ¿Cómo sabe la base de datos qué puede ver el cliente? | Al canjear el código, la función `canjear_codigo` guarda "este usuario anónimo es el cliente N del realizador R". Las reglas usan `es_cliente_de()` para dejarle leer solo sus cotizaciones y rodajes. |
| ¿Por qué el cliente no entra con Google? | La app de Google está en modo Prueba: solo entran correos agregados a mano (máximo 100). Además el cliente no necesita permisos de Gmail ni Calendar. Un código es más simple para él. |
| ¿Puede el cliente cambiar un precio? | No. Solo puede insertar respuestas y solicitudes en tablas aparte; el realizador las aplica. |
| ¿Qué pasa sin internet? | Todo se guarda primero en el teléfono (`SharedPreferences`). Al volver la red, se sube a la nube. |
| ¿Cómo se sincroniza? | Cada cambio programa una subida 2 s después (si hay varios cambios seguidos, sube una vez). Primero clientes, porque cotizaciones y trabajos dependen de ellos. |
| ¿Por qué `ChangeNotifier` y no Provider/Bloc? | Para el tamaño del proyecto basta, es lo visto en clase y no agrega dependencias. |
| ¿Cómo detecta cruces? | Mismo día y menos de 4 horas entre inicios (`conflictosPara` en `tienda.dart`). |
| ¿Cómo calcula el total? | Subtotal de ítems − descuento % + IVA 19 % si está activo (`Cotizacion` en `modelos.dart`; la nube usa el mismo cálculo). |
| ¿Por qué el correo se ve igual a tu portafolio? | Es HTML con tablas y estilos en línea (Gmail borra las hojas de estilo), ancho 600 px, y la paleta del portafolio. Siempre va también en texto plano. |
| ¿Cómo lo probaste? | `flutter analyze` sin avisos y 16 pruebas: lógica, integraciones sin red, portal del cliente y un recorrido automático de 180 toques sin errores ni desbordes a 390 px. Además pruebas manuales del 22 nov en emulador y navegador. |
| ¿Qué no está probado? | Actualizar/borrar el evento al reprogramar/cancelar, invitación al cliente, novedades al agendar/pagar, "pedir cambios" de punta a punta y el APK en celular real. |
| ¿Por qué WhatsApp no adjunta el PDF? | Sin la API de pago de WhatsApp Business un enlace `wa.me` solo lleva texto. Por eso hay un botón aparte para compartir el PDF. |

## Checklist del día

**Un día antes**
- [ ] Abrir el panel de Supabase o la app para **despertar el proyecto** (se pausa tras ~7 días sin uso).
- [ ] Si el profesor va a entrar como **realizador**, agregar su correo en Google Cloud →
      Pantalla de consentimiento → *Usuarios de prueba* (ver `GOOGLE_CLOUD_SETUP.md`). Como
      cliente no hace falta.
- [ ] Tener una cotización **Enviada** a un cliente cuyo correo puedas abrir en la demo.
- [ ] Copiar los **códigos** `CLQ-…` de 1–2 clientes (ficha del cliente → copiar) en una nota.
- [ ] Revisar que exista `dart_defines.json` con las tres claves.
- [ ] Correr `flutter analyze` y `flutter test`.

**Antes de entrar**
- [ ] Emulador encendido y la app corriendo con `--dart-define-from-file=dart_defines.json`.
- [ ] Sesión de Google iniciada y **Ajustes → Nube** en "Al día".
- [ ] Navegador (o el enlace de Netlify, si ya está) listo en la pantalla de entrada del cliente.
- [ ] Gmail y Google Calendar abiertos en otra pestaña para mostrar el correo y el evento.
- [ ] Internet estable (tener datos del celular como respaldo).
- [ ] Permiso de ubicación ya concedido en el emulador (o saber aceptarlo al abrir "Agendar trabajo").
- [ ] Evidencia de respaldo abierta: `docs/PRUEBA_CLICS.md` y capturas del correo y del evento.
