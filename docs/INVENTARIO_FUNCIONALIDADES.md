# Inventario de funcionalidades — Claqueta

Proyecto integrador · Lenguaje de Programación para APPs · Momento evaluativo 2.
Estado honesto de cada funcionalidad: **Completa** (funciona de punta a punta y se puede demostrar),
**Parcial** (funciona con una parte simulada) o **Planificada** (aún no).

Alcance acordado: 12 funcionalidades. Completas: 12 (100 %).
Requisito del curso: mínimo 6 planificadas, al menos 3 completas y, si hay más de 6, completar la mitad.

| # | Funcionalidad | Estado | Dónde se ve | Cómo demostrarla (30 s) |
|---|---|---|---|---|
| F1 | Clientes: alta, edición, búsqueda, borrado con validación | Completa | `clientes.dart`, `formulario_cliente.dart`, `detalle_cliente.dart` | Clientes → Nuevo → guardar → buscarlo |
| F2 | Cotizaciones a la carta: ítems, cantidades, descuento %, IVA 19 % opcional, total en vivo | Completa | `nueva_cotizacion.dart`, `Cotizacion` en `modelos.dart` | Cotizar → Nueva → elegir cliente, agregar 3 videos y 10 fotos → ver total |
| F3 | Catálogo de servicios y paquetes con descuento | Completa | `catalogo.dart` | Cotizar → Catálogo → crear paquete → aplicarlo en una cotización |
| F4 | Estados de cotización (Borrador → Enviada → Aceptada / Rechazada), duplicar y editar | Completa | `detalle_cotizacion.dart` | Abrir cotización → cambiar estado |
| F5 | PDF de la cotización y del catálogo con la identidad de la marca | Completa | `pdf_documentos.dart`, `pdf_vista.dart` | Detalle de cotización → ver PDF |
| F6 | Compartir por WhatsApp (mensaje listo) y por correo / menú compartir | Completa | `envio_cotizacion.dart`, `compartir.dart` | Enviar → WhatsApp (abre `wa.me` con el texto) |
| F7 | Agenda semanal con detección de cruces de horario | Completa | `agenda.dart`, `Tienda.conflictosPara` | Agendar dos trabajos el mismo día con menos de 4 h de diferencia → aparece "Cruce de agenda" |
| F8 | Finanzas: cobrado, por cobrar, aceptado, gráfica 6 meses, tasa de aceptación, mejores clientes (calculado desde cotizaciones y pagos) | Completa | `finanzas.dart` | Registrar un pago en un trabajo → cambia Finanzas |
| F9 | Seguimiento: aviso cuando una cotización enviada lleva N días sin respuesta + mensaje de recordatorio | Completa | `inicio.dart`, `Tienda.porSeguimiento` | Inicio → "Requiere tu atención" |
| F10 | Persistencia local y copia de seguridad (exportar / restaurar / restablecer) | Completa | `tienda.dart`, `ajustes.dart` | Crear un cliente → cerrar y abrir la app → sigue ahí |
| F11 | Mapa, búsqueda de direcciones, clima real y plan B (fechas sin lluvia y sin cruces) | Completa | `servicios/lugares_api.dart` (OpenStreetMap/Nominatim), `servicios/clima_api.dart` (Open-Meteo), `widgets.dart` (`MapaLugar`, `TarjetaClima`) | Agendar → escribir "Parque Arví" → elegir resultado → aparece el mapa real y el pronóstico; "Cómo llegar" abre Google Maps. Más de 16 días: el clima se marca **Estimado** |
| F12 | Login con Google, envío por Gmail (correo con la identidad de marca + PDF adjunto) y eventos en Google Calendar (crear, invitar, reprogramar, borrar) | Completa · probada con cuenta real el 22 nov 2026 (login, correo recibido en Gmail y evento visible en Google Calendar) | `servicios/google_api.dart`, `entrada.dart`, `envio_cotizacion.dart`, `agendar_trabajo.dart`, `detalle_trabajo.dart` | Requiere el ID de cliente (ver `docs/GOOGLE_CLOUD_SETUP.md`). Sin él, la app funciona en **modo demostración** y lo dice en pantalla |

Conteo: **F1–F12 completas (12 de 12, 100 % del alcance)**.
La búsqueda de direcciones prioriza la ciudad donde estás (ubicación aproximada, con permiso al abrir "Agendar trabajo").

¿Por qué OpenStreetMap y Open-Meteo y no Google Maps/Weather? Las APIs de Google Maps
exigen activar facturación en Google Cloud. OpenStreetMap y Open-Meteo son gratuitos, no
piden clave y no guardan secretos en la app. Para la ruta, el botón "Cómo llegar" abre
Google Maps por enlace (sin clave).

Evidencia de pruebas: `flutter test` (lógica, integraciones sin internet y recorrido
automático clic por clic de las 17 pantallas → `docs/PRUEBA_CLICS.md`).

## Pantallas (17), todas navegables

Entrada · Conectar con Google · Inicio · Cotizar · Nueva cotización · Detalle de cotización · Envío ·
Vista de PDF · Catálogo y paquetes · Agenda · Agendar trabajo · Detalle de trabajo · Finanzas ·
Clientes · Detalle de cliente · Formulario de cliente · Ajustes.

## Límites conocidos (para decirlos en la sustentación)

- WhatsApp sin la API de pago no adjunta el PDF desde un enlace: se comparte el PDF aparte con el menú del teléfono.
- Los precios del catálogo son de ejemplo.
- Las llaves de Google nunca van en el repositorio: el ID de cliente se pasa al compilar con `--dart-define` y no se usa Client Secret.
- La app de Google está en modo "Prueba": solo pueden entrar los usuarios de prueba agregados en Google Cloud.
- El pronóstico real cubre 16 días; más allá, el clima es estimado y se marca así.
- Inicio de sesión real con Google solo en Android; en la versión web se usa el modo demostración.
