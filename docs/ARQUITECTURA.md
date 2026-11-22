# Arquitectura — Claqueta

Resumen en una frase: **las pantallas dibujan, la tienda decide, los servicios hablan con
afuera.** Cada capa solo conoce a la de abajo, así la lógica se prueba sin abrir la app y
una API externa se puede cambiar sin tocar las pantallas.

## 1. Capas

```
┌──────────────────────────────────────────────────────────────────────────┐
│ PANTALLAS  lib/pantallas/*.dart (realizador, 17)                         │
│            lib/pantallas/cliente/*.dart (portal del cliente)             │
│            Solo dibujan y llaman a la tienda o a un servicio.            │
│            Escuchan cambios con ListenableBuilder.                       │
└───────────────┬───────────────────────────────────────┬──────────────────┘
                │ lee / llama                           │ lee / llama
┌───────────────▼──────────────────────┐   ┌────────────▼─────────────────┐
│ TIENDA  lib/tienda.dart              │   │ PORTAL  servicios/           │
│ ChangeNotifier único del realizador: │   │ portal_cliente.dart          │
│ listas, totales, cruces, plan B,     │   │ ChangeNotifier del cliente   │
│ finanzas, seguimiento, códigos.      │   │ (solo lectura + respuestas)  │
│ Guarda en SharedPreferences.         │   └────────────┬─────────────────┘
│ Ganchos: alGuardar · alNovedad       │                │
└───────────────┬──────────────────────┘                │
                │ (los ganchos los conecta la nube)     │
┌───────────────▼───────────────────────────────────────▼──────────────────┐
│ SERVICIOS  lib/servicios/                                                │
│  nube.dart        clima_api.dart   lugares_api.dart   ubicacion.dart     │
│  google_api.dart  correo_html.dart                                       │
└──────┬──────────────┬──────────────┬──────────────┬──────────────┬───────┘
       │              │              │              │              │
┌──────▼─────┐ ┌──────▼─────┐ ┌──────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
│ Supabase   │ │ Open-Meteo │ │ OpenStreet- │ │ Gmail API  │ │ Google     │
│ PostgreSQL │ │ (clima)    │ │ Map         │ │ (enviar)   │ │ Calendar   │
│ + Auth+RLS │ │ sin clave  │ │ Nominatim + │ │            │ │ API        │
│            │ │            │ │ teselas     │ │            │ │            │
└────────────┘ └────────────┘ └─────────────┘ └────────────┘ └────────────┘
```

| Capa | Archivos | Responsabilidad |
|---|---|---|
| Modelos | `modelos.dart` | Datos puros (`Cliente`, `Servicio`, `Paquete`, `Cotizacion`, `ItemCot`, `Trabajo`, `Pago`, `Config`) con `toJson`/`fromJson`. No saben nada de la interfaz |
| Tienda | `tienda.dart` | Estado único del realizador y reglas de negocio. Avisa a las pantallas con `notifyListeners()` |
| Servicios | `servicios/*.dart` | Un archivo por sistema externo. Errores traducidos a mensajes en español |
| Pantallas | `pantallas/**` | Interfaz; reutilizan los componentes de `estilo.dart` y `widgets.dart` |

**Por qué `ChangeNotifier` y no Provider/Bloc:** es lo visto en clase, no agrega
dependencias y para el tamaño del proyecto basta un estado central. Se puede explicar
completo.

**Navegación:** `IndexedStack` con 5 pestañas (Inicio, Cotizar, Agenda, Finanzas, Clientes)
más `Navigator.push` para el resto. El portal del cliente tiene su propio `IndexedStack`
con 4 pestañas (Inicio, Cotizaciones, Solicitar, Novedades) y el mismo `DockNav`.

**Arranque (`main.dart`):** carga los datos locales → recupera la sesión de Google en
segundo plano → inicia Supabase (si falla, sigue local) → si el teléfono quedó en "modo
cliente", restaura esa sesión. Luego elige la primera pantalla: portal del cliente,
app del realizador (si hay sesión) o la pantalla de entrada.

## 2. Flujo de datos: local primero, nube después

```
  Pantalla ──► tienda.guardarX()/cambiarEstado()/registrarPago()
                    │
                    ▼
               _cambio()
                 ├─► SharedPreferences  (clave "claqueta-v2", JSON)   ← siempre, sin red
                 ├─► notifyListeners()  → las pantallas se redibujan
                 └─► alGuardar()        → nube._programarSubida()
                                              │ espera 2 s (debounce)
                                              ▼
                                         subir(): upsert por tabla
                                         clientes → servicios → paquetes →
                                         cotizaciones → trabajos → config,
                                         y borra en la nube lo eliminado
```

- **Local primero:** la app nunca espera a internet. Si no hay red o Supabase falla, los
  datos siguen en el teléfono y el estado de la nube queda en "error" en Ajustes.
- **Debounce de 2 s:** si el usuario hace cinco cambios seguidos, se sube una sola vez.
- **Orden de subida:** primero clientes, porque cotizaciones y trabajos tienen llave
  foránea hacia el cliente. Al borrar se va en orden inverso.
- **Ganchos (`alGuardar`, `alNovedad`):** son funciones que la tienda llama sin saber quién
  las escucha. La tienda no importa Supabase; `nube.dart` se "engancha" al iniciar. Así la
  tienda se prueba sin red y la nube se podría cambiar por otra.
- **`alNovedad`:** la tienda avisa eventos para el cliente (cotización enviada o aceptada,
  rodaje agendado, reprogramado o cancelado, pago registrado) y la nube los inserta en la
  tabla `novedades`.

**Recuperar al reinstalar** (`conectarNube` en `selectores.dart`):

| Situación al conectar | Qué hace la app |
|---|---|
| La nube está vacía | Sube los datos del teléfono |
| La nube tiene datos | Muestra "Encontré tus datos en la nube" con el conteo y ofrece **Traerlos a este teléfono** o **Reemplazarlos con los de este teléfono** |

Probado el 22 nov 2026: desinstalar → reinstalar → entrar con Google → "Traerlos a este
teléfono" → datos recuperados.

**Entrada a Supabase con Google:** la app reutiliza el *ID token* que entrega Google
Sign-In y llama `signInWithIdToken`. El usuario no crea otra cuenta.

## 3. Modelo de datos en Supabase

Cada tabla del realizador tiene columnas legibles (para consultar y filtrar) y una columna
`datos` (`jsonb`) con el objeto completo que usa la app. Así la base de datos es
consultable y la app no necesita convertir campo por campo.

### Tablas del realizador (`supabase/esquema.sql`)

| Tabla | Llave primaria | Columnas legibles | Relación |
|---|---|---|---|
| `clientes` | `(user_id, id)` | nombre, correo, telefono, codigo | — |
| `servicios` | `(user_id, id)` | nombre, precio | — |
| `paquetes` | `(user_id, id)` | nombre | — |
| `cotizaciones` | `(user_id, n)` | cliente_id, proyecto, estado, total | → `clientes` (on delete cascade) |
| `trabajos` | `(user_id, id)` | cliente_id, cot_n, titulo, fecha, lugar, valor | → `clientes` (on delete cascade) |
| `config` | `user_id` | — | una fila por realizador |

Todas llevan `user_id uuid default auth.uid()` (el dueño) y `actualizado`.

**RLS:** una sola regla en las seis tablas, **"solo lo mío"**:
`using (auth.uid() = user_id) with check (auth.uid() = user_id)`. Además, a los usuarios
`anon` (sin sesión) se les revocan todos los permisos.

### Tablas del portal (`supabase/portal_cliente.sql`)

| Tabla | Quién escribe | Quién lee | Para qué |
|---|---|---|---|
| `accesos_cliente` | La función `canjear_codigo` | El propio cliente y su realizador | "Este usuario anónimo es el cliente N del realizador R" |
| `solicitudes` | Cliente (insert) · realizador (cambia estado) | Ambos | Pedido de cotización nueva (Nueva · En cotización · Descartada) |
| `respuestas` | Cliente (insert) · realizador (marca procesada) | Ambos | `aceptar` o `cambios` sobre una cotización |
| `novedades` | Realizador | Ambos | Avisos al cliente |

Reglas extra de lectura para el cliente, usando la función `es_cliente_de(r, c)`:
puede leer **su** ficha en `clientes`, **sus** `cotizaciones` y **sus** `trabajos`, y el
nombre del negocio en `config`. Nunca puede insertar, cambiar ni borrar datos del
realizador: sus acciones van a tablas aparte.

`es_cliente_de` y `canjear_codigo` son `security definer`: se ejecutan con permisos del
dueño de la base para poder consultar `accesos_cliente` sin caer en un ciclo de reglas RLS.

## 4. Portal del cliente: dos roles en la misma app

```
 REALIZADOR (Google)                         CLIENTE (anónimo + código)
 ───────────────────                         ──────────────────────────
 Ficha del cliente: código CLQ-XXXXXX ──WhatsApp──► "Soy cliente · tengo un código"
                                                    signInAnonymously()
                                                    rpc canjear_codigo(código)
                                                       └► accesos_cliente
 cotizaciones / trabajos (RLS) ──── lectura ──────► ve solo lo suyo (sin borradores)
                                                    Aceptar / Pedir cambios ─► respuestas
                                                    Solicitar ───────────────► solicitudes
 revisarBandeja() cada 1 min ◄─────────────────────
   · "aceptar"  → la cotización pasa a Aceptada sola
   · "cambios" y solicitudes → "Requiere tu atención" en Inicio
 tienda.avisar() → alNovedad ──► novedades ────────► pestaña Novedades (contador de no leídas)
```

- **Código de invitación:** la tienda genera `CLQ-` + 6 caracteres con `Random.secure()`,
  sin caracteres que se confunden (0/O, 1/I/L). Hay índice único sin importar mayúsculas.
- **Sesión del cliente:** el rol "cliente" se guarda en el teléfono (`claqueta-rol`) y la
  sesión anónima la conserva Supabase; al recargar se restaura (probado en web).
- **Borradores ocultos:** el cliente solo ve cotizaciones que el realizador ya envió.
- **Revisión cada minuto (polling)** en lugar de tiempo real: es más simple de explicar y
  de depurar, y para este uso un minuto de retraso no importa.

Probado el 22 nov 2026: el cliente en web acepta COT-0044 → pasa a Aceptada en la app del
realizador; una solicitud del cliente aparece en "Requiere tu atención".

## 5. Integraciones externas

| Servicio | Archivo | Clave | Qué hace |
|---|---|---|---|
| OpenStreetMap / Nominatim | `lugares_api.dart`, `ubicacion.dart` | No | Busca direcciones (solo Colombia); primero en ~30 km alrededor del usuario, luego en todo el país; ordena por cercanía. Respeta su regla de 1 consulta/s (espera a que dejes de escribir) y envía `User-Agent` |
| Teselas de OSM (`flutter_map`) | `widgets.dart` (`MapaLugar`) | No | Mapa real del lugar del rodaje |
| Google Maps (enlace) | `lugares_api.dart` (`enlaceGoogleMaps`) | No | Botón "Cómo llegar": abre la ruta por URL |
| Open-Meteo | `clima_api.dart` | No | Pronóstico diario de 16 días; se guarda en memoria por ubicación. Más allá de 16 días o sin red: clima **Estimado** (marcado así) |
| Ubicación aproximada | `ubicacion.dart` (`geolocator`) | No | Permiso `ACCESS_COARSE_LOCATION` al abrir "Agendar trabajo"; solo nivel ciudad |
| Google Sign-In 7 | `google_api.dart` | ID de cliente web | Login con dos scopes: `gmail.send` y `calendar.events` |
| Gmail API | `google_api.dart`, `correo_html.dart` | (token del login) | Envía correo MIME con versión HTML de marca + texto plano + PDF adjunto |
| Google Calendar API | `google_api.dart` | (token del login) | Crea el evento del rodaje (con invitado opcional); hay funciones para actualizar y eliminar |
| Supabase | `nube.dart`, `portal_cliente.dart` | URL + anon key | Base de datos, autenticación (Google e anónima) y RLS |

Cada integración se puede apagar en **Ajustes** (`maps`, `clima`, `calendar`, `gmail`).
Sin coordenadas o con el mapa apagado se dibuja un mapa de referencia (`MapaSimulado`),
que es solo un marcador visual mientras se elige la dirección.

## 6. Seguridad

| Medida | Cómo | Por qué |
|---|---|---|
| Claves fuera del repositorio | `dart_defines.json` (en `.gitignore`) → `--dart-define-from-file`; se leen con `String.fromEnvironment` | Si el código se publica en GitHub no se filtra nada |
| Sin Client Secret | Se usa solo el ID de cliente "web", que es público | Una app móvil no puede guardar secretos: cualquiera puede descompilar el APK |
| Permisos mínimos de Google | Solo `gmail.send` (no lee la bandeja) y `calendar.events` (no ve otros calendarios). Hay una prueba que lo verifica | Si el token se filtrara, el daño posible es mínimo |
| Clave *anon* pública a propósito | La protege RLS en cada tabla; la `service_role` nunca va en la app | Es el modelo de seguridad de Supabase: el permiso lo decide la base de datos, no la app |
| RLS "solo lo mío" | `auth.uid() = user_id` | Aunque alguien use la clave pública, no ve datos de otro realizador |
| El cliente no escribe datos del realizador | Solo inserta en `respuestas` y `solicitudes`; las aplica el realizador | Un cliente no puede cambiar precios ni estados directamente |
| Ubicación aproximada | Solo `ACCESS_COARSE_LOCATION` | Basta saber la ciudad; es más privado |
| Correo seguro | Todo texto del usuario se escapa (`&`, `<`, `>`) antes de ir al HTML | No se rompe el correo ni se inyecta código. Hay prueba |

## 7. Decisiones y por qué

| Decisión | Alternativa descartada | Razón |
|---|---|---|
| OpenStreetMap + Open-Meteo | Google Maps / Places / Weather | Google Maps exige activar facturación (tarjeta) en Google Cloud. OSM y Open-Meteo son gratis, sin clave y sin secretos. La ruta se resuelve con un enlace a Google Maps, que no pide clave |
| Supabase (PostgreSQL) | Firebase, backend propio | Base de datos relacional con llaves foráneas (se explica con lo visto en bases de datos), RLS declarativo en SQL, login con Google por ID token y plan gratis |
| Local primero + copia en la nube | Solo nube | La app funciona en rodaje sin señal; la nube es respaldo y canal con el cliente |
| Código de invitación para clientes | Que el cliente entre con Google | La app de Google está en modo **Prueba**: solo entran hasta 100 usuarios agregados a mano, y publicarla exige la verificación de Google. Además los permisos de Gmail/Calendar no tienen sentido para el cliente. Un código + sesión anónima no pide cuenta ni correo |
| Novedades en tabla (la app del cliente las lee) | Enviar correo al cliente por cada aviso | Evita depender de los límites de envío de Gmail y de pedirle más permisos al realizador *(supuesto: los límites exactos de envío de Gmail no se verificaron en este proyecto)* |
| Revisar la bandeja cada minuto | Supabase Realtime | Más simple, menos piezas que fallen en la demo |
| `ChangeNotifier` + ganchos | Provider, Bloc, Riverpod | Sin dependencias extra y explicable en clase |

## 8. Limitaciones conocidas

- **Modo Prueba de Google:** solo entran como realizador los correos agregados como usuarios
  de prueba; aparece el aviso "Google no verificó esta app" → Continuar.
- **Login con Google solo en Android.** En web, Google queda en modo demostración. El portal
  del cliente sí funciona en web.
- **Plan gratis de Supabase:** el proyecto se pausa tras ~7 días sin uso; hay que
  "despertarlo" antes de presentar.
- **Clima:** pronóstico real solo 16 días; después es estimado.
- **Nominatim:** máximo 1 consulta por segundo; los resultados dependen de cómo esté
  cargado el lugar en OpenStreetMap.
- **WhatsApp:** sin la API de pago no se adjunta el PDF desde un enlace.
- **Sincronización "último gana":** la subida reemplaza la copia en la nube con la del
  teléfono. Si el mismo realizador usa dos teléfonos a la vez, el último que guarda manda.
- **Retraso del portal:** hasta 1 minuto entre la acción del cliente y que la vea el realizador.
- **Sin probar todavía de punta a punta:** actualizar/borrar el evento de Calendar al
  reprogramar/cancelar, invitación al cliente en el evento, novedades al agendar/pagar,
  "pedir cambios" completo y el APK en un celular real. Ver [PRUEBAS.md](PRUEBAS.md).
- **En curso:** ícono propio, nombre "Claqueta" en el teléfono, versión web para Netlify y
  sesión de Google persistente.
- Los precios del catálogo son de ejemplo.

## Paquetes

`google_fonts`, `shared_preferences`, `pdf`, `printing`, `url_launcher`, `http`,
`flutter_map`, `latlong2`, `google_sign_in`, `geolocator`, `supabase_flutter`.
