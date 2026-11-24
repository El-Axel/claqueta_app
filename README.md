# Claqueta

App móvil (Flutter) para **realizadores audiovisuales freelance**: cotiza, agenda y cobra
desde el celular. Tiene además un **portal para los clientes** del realizador, donde ven y
aceptan sus cotizaciones.

Proyecto integrador · Alexander Pino Caro · Diseño Crossmedia, UCC (Colombia).
Todo en español, moneda COP. Identidad "Pizarrón": fondo petróleo oscuro, un solo acento
arena, tipografías Krona One + Figtree.

## Qué hace (resumen)

13 funcionalidades, todas completas. Detalle y forma de demostrar cada una en
[docs/INVENTARIO_FUNCIONALIDADES.md](docs/INVENTARIO_FUNCIONALIDADES.md).

| Área | Qué hace |
|---|---|
| Clientes | Alta, edición, búsqueda, borrado con validación; cada cliente tiene un código de invitación `CLQ-XXXXXX` |
| Catálogo | Servicios con precio por unidad y paquetes con descuento; catálogo en PDF |
| Cotizar | Cotización "a la carta" (3 videos, 10 fotos…), descuento %, IVA 19 % opcional, total en vivo; editar y duplicar |
| Estados | Borrador → Enviada → Aceptada / Rechazada, con línea de progreso |
| Envío | PDF con la identidad de marca; **Gmail** con correo HTML de marca + PDF adjunto; WhatsApp con el mensaje listo |
| Seguimiento | Aviso cuando una cotización enviada lleva N días sin respuesta |
| Agenda | Semana navegable, detección de cruces de horario, plan B (fechas sin lluvia y sin cruces) |
| Agendar | Búsqueda de direcciones (**OpenStreetMap**), mapa real, clima real (**Open-Meteo**), evento en **Google Calendar** |
| Finanzas | Cobrado, por cobrar, aceptado, gráfica de 6 meses, tasa de aceptación, mejores clientes |
| Nube | Copia automática en **Supabase** (PostgreSQL con seguridad por fila); recuperación al reinstalar |
| Portal del cliente | El cliente entra con su código, ve sus cotizaciones y rodajes, acepta o pide cambios, solicita cotizaciones y recibe novedades |

Sin internet la app sigue funcionando: todo se guarda primero en el teléfono.

## Cómo ejecutarla

Requisitos: Flutter (SDK de Dart ≥ 3.3) y un emulador Android, un celular o Chrome.

```powershell
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` va en la raíz del proyecto, **no se sube a git** (está en `.gitignore`)
y tiene este formato (pon tus valores; aquí van vacíos a propósito):

```json
{
  "GOOGLE_WEB_CLIENT_ID": "",
  "SUPABASE_URL": "",
  "SUPABASE_ANON_KEY": ""
}
```

| Clave | Qué es | Dónde se obtiene |
|---|---|---|
| `GOOGLE_WEB_CLIENT_ID` | ID de cliente OAuth "web" de Google (público; **no** se usa Client Secret) | [docs/GOOGLE_CLOUD_SETUP.md](docs/GOOGLE_CLOUD_SETUP.md) |
| `SUPABASE_URL` | Dirección del proyecto de Supabase | [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) |
| `SUPABASE_ANON_KEY` | Clave pública *anon/publishable* (la protege RLS). **Nunca** la `service_role` | [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) |

Qué pasa si falta alguna clave:

- Sin `GOOGLE_WEB_CLIENT_ID` (o en la versión web): Google entra en **modo demostración**;
  se ven los pasos pero no se envía correo ni se crea el evento, y la pantalla lo dice.
- Sin las claves de Supabase: no hay nube ni portal del cliente; la app funciona solo en el
  teléfono.
- Mapa y clima no necesitan clave.

APK para entregar: `flutter build apk --dart-define-from-file=dart_defines.json`.

## Guías

| Documento | Para qué |
|---|---|
| [INVENTARIO_FUNCIONALIDADES.md](docs/INVENTARIO_FUNCIONALIDADES.md) | Las 13 funcionalidades, estado y cómo demostrarlas |
| [ARQUITECTURA.md](docs/ARQUITECTURA.md) | Capas, flujo de datos local + nube, tablas, seguridad y decisiones |
| [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Colores, tipografías, componentes, correo HTML y portal |
| [SUSTENTACION.md](docs/SUSTENTACION.md) | Guion de demostración, preguntas del jurado y checklist del día |
| [PRUEBAS.md](docs/PRUEBAS.md) | Pruebas automáticas y pruebas manuales hechas / pendientes |
| [SEGURIDAD.md](docs/SEGURIDAD.md) | CAPTCHA (Turnstile), límite de intentos del código y cómo activarlos |
| [CUENTAS.md](docs/CUENTAS.md) | Cuentas con correo y contraseña: dónde se guardan y qué activar en Supabase |
| [GOOGLE_CLOUD_SETUP.md](docs/GOOGLE_CLOUD_SETUP.md) | Configurar Gmail y Calendar en Google Cloud (sin facturación) |
| [SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) | Crear la base de datos, el login y el portal del cliente |
| [PRUEBA_CLICS.md](docs/PRUEBA_CLICS.md) | Informe de la prueba automática clic por clic |

## Estructura

```
lib/
  main.dart              arranque: carga datos, Google, nube y decide la primera pantalla
  tema.dart              tokens: Paleta, fuentes, colores por estado, ThemeData
  estilo.dart            estilo limpio: fondo, dock, TarjetaSuave, EtiquetaSeccion…
  widgets.dart           piezas comunes: Panel, botones, filas, mapa, clima, campos, hojas
  modelos.dart           Cliente, Servicio, Paquete, Cotizacion, Trabajo, Pago, Config
  tienda.dart            estado + lógica (ChangeNotifier) + guardado local
  util.dart              pesos, fechas, clima estimado, lugares de ejemplo
  pdf_documentos.dart    PDF de cotización y de catálogo
  compartir.dart         mensajes y enlaces de WhatsApp / correo
  selectores.dart        selector de cliente y decisión al conectar la nube
  servicios/
    clima_api.dart       Open-Meteo (pronóstico 16 días)
    lugares_api.dart     OpenStreetMap / Nominatim (direcciones) + enlace a Google Maps
    ubicacion.dart       ubicación aproximada (ciudad) con permiso
    google_api.dart      login con Google, Gmail y Calendar
    correo_html.dart     correo HTML con la identidad de marca
    nube.dart            Supabase: subir, bajar, bandeja del realizador
    portal_cliente.dart  lo que ve y hace el cliente
  pantallas/             17 pantallas del realizador
  pantallas/cliente/     portal del cliente (código, inicio, cotizaciones, rodaje, solicitar, novedades)
supabase/
  esquema.sql            tablas del realizador + seguridad por fila
  portal_cliente.sql     tablas y reglas del portal + función canjear_codigo
test/                    16 pruebas automáticas (ver docs/PRUEBAS.md)
docs/                    documentación
```

`lib/vidrio.dart` es una versión anterior del estilo ("vidrio") que ya no importa ninguna
pantalla; se conserva como referencia.

## Pruebas

```powershell
flutter analyze   # sin avisos
flutter test      # 16 pruebas: lógica, integraciones sin red, portal y recorrido clic por clic
```

La prueba clic por clic toca 180 elementos de las 17 pantallas a tamaño de teléfono
(390 × 844): 0 errores y 0 desbordes. Detalle en [docs/PRUEBAS.md](docs/PRUEBAS.md).

## Dónde cambiar cada cosa

| Quiero cambiar… | Archivo |
|---|---|
| Colores o fuentes | `lib/tema.dart` (`Paleta`, `estiloDisplay`) |
| Radio y transparencia de las tarjetas | `lib/estilo.dart` (`radioTarjeta`, `decoracionSuave`) |
| Cómo se calcula un total | `Cotizacion` en `lib/modelos.dart` (lo usan pantalla, PDF y finanzas) |
| Reglas de cruce o plan B | `conflictosPara` y `alternativas` en `lib/tienda.dart` |
| Diseño del PDF | `lib/pdf_documentos.dart` |
| Diseño del correo | `lib/servicios/correo_html.dart` |
| Textos de WhatsApp | `lib/compartir.dart` |
| Datos de ejemplo | `_sembrar()` en `lib/tienda.dart` |
| Tablas o reglas de seguridad | `supabase/*.sql` |

## Límites conocidos

- WhatsApp sin la API de pago no adjunta el PDF desde un enlace: el PDF se comparte aparte.
- Los precios del catálogo son de ejemplo.
- El realizador entra con su **cuenta de Claqueta** (correo y contraseña, ver
  [docs/CUENTAS.md](docs/CUENTAS.md)). La app de Google está en modo **Prueba**: solo los
  usuarios de prueba agregados en Google Cloud pueden **conectar Gmail y Calendar**.
- Login real con Google solo en Android; en web, modo demostración (el portal del cliente sí
  funciona en web porque usa código, no Google).
- En el plan gratis, Supabase pausa el proyecto tras ~7 días sin uso.

Más detalle en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md#limitaciones-conocidas).
