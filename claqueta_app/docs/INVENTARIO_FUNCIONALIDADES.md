# Inventario de funcionalidades — Claqueta

Proyecto integrador · Lenguaje de Programación para APPs · Momento evaluativo 2.
Estado honesto de cada funcionalidad: **Completa** (funciona de punta a punta y se puede demostrar),
**Parcial** (funciona con una parte simulada) o **Planificada** (aún no).

Alcance acordado: 12 funcionalidades. Completas: 9 (75 %). Parciales: 3.
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
| F11 | Clima y plan B (fechas sin lluvia y sin cruces) | Parcial | `util.dart` (`climaDe`), `detalle_trabajo.dart` | El clima se **simula** por fecha; el plan B sí es real. En la versión final: Google Weather API |
| F12 | Login con Google, mapa/lugares y evento en Calendar | Parcial | `entrada.dart`, `agendar_trabajo.dart` | Flujo completo pero **simulado**. En la versión final: `google_sign_in`, Maps y Calendar API con permisos mínimos |

Conteo: **F1–F10 completas (10), F11–F12 parciales (2)**. Total 12, 83 % del alcance completo.

## Pantallas (17), todas navegables

Entrada · Conectar con Google · Inicio · Cotizar · Nueva cotización · Detalle de cotización · Envío ·
Vista de PDF · Catálogo y paquetes · Agenda · Agendar trabajo · Detalle de trabajo · Finanzas ·
Clientes · Detalle de cliente · Formulario de cliente · Ajustes.

## Límites conocidos (para decirlos en la sustentación)

- WhatsApp sin la API de pago no adjunta el PDF desde un enlace: se comparte el PDF aparte con el menú del teléfono.
- Los precios del catálogo son de ejemplo.
- Las llaves de Google nunca van en el repositorio.
