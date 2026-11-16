# Claqueta (Flutter) — avance v0.2

App para realizadores audiovisuales freelance: cotiza, agenda y cobra.
Identidad Pizarrón (teal/arena, Krona One + Figtree). Todo en español, moneda COP.

## Cómo correrla

1. Descomprime y abre la carpeta en VS Code (o la terminal).
2. Genera las carpetas de plataforma (Android, web, etc.). Solo la primera vez:
   ```
   flutter create --project-name claqueta .
   ```
   No pisa `lib/` ni `pubspec.yaml`.
3. Instala los paquetes y corre:
   ```
   flutter pub get
   flutter run -d chrome        # o un emulador / tu celular
   ```
4. Pruebas de la lógica (opcional): `flutter test`

**Android:** agrega en `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
</queries>
```
(INTERNET es para descargar las fuentes y abrir WhatsApp.)

> Esta versión no pudo compilarse donde se escribió (no había Flutter instalado):
> el código se revisó a mano y con un analizador de sintaxis. Si `flutter run`
> muestra algún error, pega el mensaje completo y se corrige.

## Qué hace

| Área | Funciones |
|---|---|
| Acceso | Login con Google (simulado: cuenta → permisos), sesión recordada |
| Inicio | Resumen, próximo rodaje con clima, **alertas**: seguimiento, cruces de agenda, lluvia |
| Catálogo | Servicios con precio por unidad (video, foto, día…) y **paquetes** con descuento; catálogo en PDF |
| Cotizar | Lista con búsqueda y filtros; **nueva cotización a la carta**: anotas lo que pide el cliente (3 videos, 10 fotos…) o aplicas un paquete y el total se arma solo; descuento, IVA, notas, ítems personalizados; editar y duplicar |
| Envío | **PDF** con la identidad; mensaje personalizado editable; correo con PDF adjunto (menú compartir), **WhatsApp** con el mensaje listo, compartir PDF |
| Estados | Borrador → Enviada → Aceptada / Rechazada, con línea de progreso |
| Seguimiento | Aviso cuando una enviada lleva N días sin respuesta + mensaje de recordatorio |
| Agenda | Semana navegable, trabajos por día, **detección de cruces** de horario |
| Agendar | Cotización vinculada, fecha y hora, dirección con sugerencias, mapa, clima, **plan B** (fechas secas y libres), evento de Calendar e invitación al cliente |
| Trabajo | Datos, mapa, clima, pagos con barra de progreso, registrar pago, reprogramar con plan B, avisar por WhatsApp |
| Finanzas | Cobrado / por cobrar / aceptado, gráfica de 6 meses, tasa de aceptación, mejores clientes |
| Clientes | Lista, detalle, alta/edición con validación, contacto por WhatsApp o correo |
| Ajustes | Integraciones (se pueden apagar), IVA, vigencia, seguimiento, **copia de seguridad** (exportar/restaurar), restablecer, cerrar sesión |

Los datos se guardan en el dispositivo (clave `claqueta-v2`), igual que `localStorage` en la web.

## Qué es real y qué está simulado

- **Real:** guardado local, cálculos, PDF, compartir, enlace de WhatsApp (`wa.me`), correo, finanzas, detección de cruces y plan B.
- **Simulado (se reemplaza en la versión final):** login con Google, Google Maps (mapa dibujado + lista de lugares de ejemplo), Google Weather (clima calculado por fecha), Google Calendar (evento y invitación), Gmail API (se usa el menú compartir).
- **Límite de WhatsApp:** sin la API de pago de WhatsApp Business no se puede adjuntar el PDF desde un enlace. Por eso hay dos botones: uno abre el chat con el mensaje y otro comparte el PDF.
- Los **precios del catálogo son de ejemplo**: edítalos con tus tarifas reales.

## Estructura

```
lib/
  main.dart            arranque
  tema.dart            paleta Pizarrón, fuentes, estados
  widgets.dart         piezas reutilizables (Panel, botones, avisos, mapa…)
  modelos.dart         Cliente, Servicio, Paquete, Cotizacion, Trabajo, Pago, Config
  tienda.dart          datos + guardado + lógica (cruces, plan B, finanzas)
  util.dart            pesos, fechas, clima y lugares simulados
  pdf_documentos.dart  PDF de cotización y de catálogo
  compartir.dart       mensajes y enlaces de WhatsApp / correo
  selectores.dart      selector de cliente
  pantallas/           una pantalla por archivo
test/logica_test.dart  pruebas de totales, pagos y formato
```

## Dónde cambiar cada cosa

- Colores o fuentes: `tema.dart`.
- Cómo se calcula un total: `Cotizacion` en `modelos.dart` (un solo lugar; pantalla, PDF y finanzas lo usan).
- Reglas de cruce de agenda o plan B: `conflictosPara` y `alternativas` en `tienda.dart`.
- Diseño del PDF: `pdf_documentos.dart`.
- Textos de los mensajes: `compartir.dart`.
- Datos de ejemplo: `_sembrar()` en `tienda.dart`.

## Siguientes pasos sugeridos

1. Probar cada flujo y anotar qué cambiar.
2. Conectar Google Maps y Weather con claves propias (nunca dentro del repositorio).
3. Login real con `google_sign_in` + Gmail/Calendar (scopes `gmail.send` y `calendar.events`).
4. Dejar fuera de esta etapa: pasarela de pagos, varios usuarios y base de datos en la nube (versión 2).


## Estilo visual (v0.5: oscuro con acento)

Basado en los referentes de apps de tareas y billetera, con la identidad del Pizarrón.

- **Fondo:** casi negro (#0B1315) con una bruma teal que cae desde arriba y grano fino. Estático (sin animación ni blur: rinde mejor en celulares modestos).
- **Tarjetas** (`Panel`): oscuras, borde fino, radio 26.
- **Un solo acento:** arena (#F2C572) para botón principal, pestaña activa, chip elegido, día elegido y barra destacada. El teal queda para estados y gráficas secundarias.
- **Tarjeta hero** (`TarjetaHero`): degradado teal → arena con texto oscuro (Inicio, Finanzas, Entrada).
- **Nav** (`DockNav`): píldora oscura flotante; la pestaña activa se expande en arena con su nombre, las demás son círculos claros.
- **Componentes** en `lib/estilo.dart`: AccionRapida, BarraBrillante (resto rayado), Ficha (cuadrito con inicial), PildoraOscura, BotonPildora, BotonCirculo, Estadisticas.
- **Finanzas:** cifra grande en tarjeta hero, tres cuadros oscuros, cápsulas por mes con la mejor destacada, y el % de aceptación gigante.
- **Agenda:** tira semanal con el día elegido en arena y línea de tiempo con tarjetas oscuras y barra de color.
- Para cambiar el acento en toda la app: `Paleta.arena` en `lib/tema.dart` (y `colorScheme.primary`).
- Sin paquetes nuevos.
