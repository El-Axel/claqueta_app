# Design System — Claqueta

Todo el estilo vive en tres archivos. Para cambiar un color, una fuente o el radio de las
tarjetas basta editar un solo lugar.

| Archivo | Qué contiene |
|---|---|
| `lib/tema.dart` | **Tokens**: `Paleta`, tipografías, colores por estado, `crearTema()` |
| `lib/estilo.dart` | **Estilo limpio** (el del Home, ahora en toda la app): medidas, fondo, dock y componentes de tarjeta |
| `lib/widgets.dart` | **Componentes comunes**: botones, filas, formularios, mapa, clima, hojas y diálogos |

## 1. Tokens (`lib/tema.dart`)

### Color

| Token | Valor | Uso |
|---|---|---|
| `Paleta.suelo` | `#0B1315` | Fondo de toda la app; texto sobre el acento |
| `Paleta.panel` / `panel2` | `#132126` / `#1A2C32` | Superficies sólidas (hojas, snackbars) |
| `Paleta.petroleo` | `#2A5159` | Profundidad, resaltes |
| `Paleta.teal` | `#2EA690` | Color de marca: bruma del fondo, estado *Aceptada*, gráficas secundarias |
| `Paleta.arena` | `#F2C572` | **Único acento**: botón principal, pestaña activa, chip/día elegido, interruptores, cifras destacadas |
| `Paleta.durazno` | `#F29863` | Estado *Enviada* |
| `Paleta.terracota` | `#D9674E` | Estado *Rechazada*, alertas y peligro |
| `Paleta.tinta` | `#F4F1EA` | Texto (con transparencia para el texto secundario) |

**Colores por estado** (`coloresEstado`): Borrador → arena · Enviada → durazno ·
Aceptada → teal · Rechazada → terracota.

### Tipografía (Google Fonts)

| Uso | Fuente | Dónde |
|---|---|---|
| Marca, cifras grandes, títulos de hoja | **Krona One** | `estiloDisplay(tamano, color)` |
| Títulos de pantalla (como el saludo del Home) | **Figtree** grande en negrita | `estiloTituloPantalla()`, `Encabezado` |
| Texto general | **Figtree** | `textTheme` de `crearTema()` |
| Texto secundario | Figtree, tinta al ~60 % | `estiloSuave(tamano)` |
| Etiquetas de sección | Figtree 11 px, mayúsculas, espaciado 1.3 | `EtiquetaSeccion` |

### Tema global (`crearTema()`)

`ThemeData` oscuro con `primary = arena` y `onPrimary = suelo`. Ahí se definen **una sola
vez** divisores, interruptores, chips, botones de texto, `SegmentedButton` y snackbars, para
que todas las pantallas usen el mismo acento sin repetir estilos.

## 2. Estilo limpio (`lib/estilo.dart`)

Todas las pantallas (realizador y portal del cliente) usan el estilo del Home:

- **Fondo** (`Lienzo` + `FondoVivo`): casi negro con una bruma teal que cae desde arriba y
  grano fino. Estático, sin animación ni desenfoque.
- **Tarjetas suaves:** blanco casi transparente, radio grande y borde apenas visible; sin
  sombras ni degradados.
- **Un solo acento** arena para lo importante.
- **Etiquetas de sección** pequeñas en mayúsculas para ordenar sin gritar.

### Medidas

| Constante | Valor | Uso |
|---|---|---|
| `radioTarjeta` | `28` | Radio de `TarjetaSuave` |
| `alfaFondoSuave` | `13` (≈ 5 %) | Relleno blanco de tarjetas y campos |
| `alfaBordeSuave` | `22` (≈ 9 %) | Borde de tarjetas y campos |
| `decoracionSuave({radio, tinte})` | — | Decoración común de `TarjetaSuave`, `Panel`, campos y estados vacíos. Con `tinte` colorea apenas el fondo y el borde |

### Componentes

| Componente | Para qué |
|---|---|
| `Lienzo`, `FondoVivo` | Pantalla con el fondo de marca (reemplaza a `Scaffold`) |
| `DockNav` | Navegación inferior: píldora oscura flotante; la pestaña activa se expande en arena con su nombre. La usan el realizador (5 pestañas) y el cliente (4) |
| `TarjetaSuave` | Bloque principal de cada pantalla |
| `EtiquetaSeccion` | Título pequeño de sección |
| `DatoLinea` | Renglón con ícono tenue (hora, lugar, clima) |
| `Atajo` | Atajo cuadrado con ícono; el principal en arena |
| `CifraLado` | Cifra grande con su nombre debajo (Por cobrar, Cobrado…) |
| `BotonArena` | Píldora arena de ancho ajustado, para acciones dentro de una tarjeta |
| `BotonCirculo` | Botón circular (volver, ajustes, flechas) |
| `PildoraOscura`, `Ficha`, `Estadisticas` | Chip oscuro, cuadrito con inicial, tira de cifras |
| `TarjetaHero`, `AccionRapida`, `BarraBrillante`, `BotonPildora` | Del estilo anterior (degradado teal → arena). Siguen definidos pero **ninguna pantalla los usa** tras unificar el estilo |

## 3. Componentes comunes (`lib/widgets.dart`)

| Componente | Para qué |
|---|---|
| `Panel` | Tarjeta base (misma `decoracionSuave`, radio 24); con `color` se tiñe para resaltar |
| `BotonClaqueta` | Botón de ancho completo en píldora: `primario` (arena), `secundario` (oscuro con borde), `peligro` |
| `Etiqueta` | Píldora pequeña de color (estado, "Pronóstico" / "Estimado") |
| `Encabezado`, `TituloSeccion` | Título de pantalla y de sección (con enlace "Ver todo" en arena) |
| `FilaItem`, `FilaCot`, `FilaTrabajo`, `FilaDato` | Filas de lista y de detalle |
| `Vacio`, `Aviso` | Estado vacío y banner de aviso (seguimiento, lluvia, cruces) |
| `Cantidad`, `BarraProgreso`, `LineaEstado` | Selector − / +, progreso de pagos, línea Borrador → Enviada → Aceptada/Rechazada |
| `TarjetaClima` | Clima del rodaje: etiqueta **Pronóstico** (Open-Meteo) o **Estimado** |
| `MapaLugar` | Mapa real de OpenStreetMap con botón "Cómo llegar" (Google Maps por enlace) |
| `MapaSimulado` | Dibujo de referencia mientras no hay coordenadas o si el mapa está apagado en Ajustes |
| `decoracionCampo`, `CampoSelector` | Campos de formulario con el mismo relleno que las tarjetas |
| `hojaInferior`, `confirmar`, `mostrarAviso`, `barra`, `Pagina` | Hoja que sube, diálogo, snackbar, barra superior transparente, contenedor con scroll |

## 4. Correo HTML de marca (`lib/servicios/correo_html.dart`)

La cotización se envía por Gmail como una **"ficha de rodaje"** con el lenguaje visual del
portafolio del realizador: fondo oscuro del set, acento arena, punto **REC** terracota con
el folio, visor de cámara con esquinas, fichas tipo *ISO / DIAFRAGMA* y títulos que
terminan en punto.

| Token del correo | Valor |
|---|---|
| Fondo / panel | `#0B1315` / `#111C1F` |
| Acento | `#F2C572` (arena) |
| REC / alerta | `#D9674E` (terracota) |
| Texto / suave / tenue | `#F4F1EA` / `#A9ADA9` / `#6F7674` |
| Línea | `#22302F` |
| Fondo exterior | `#ECE8DF` (papel cálido) |

Reglas, distintas a una página web (y por qué):

- **Tablas y estilos en línea:** Gmail y Outlook borran las hojas de estilo y no entienden flexbox.
- **Ancho máximo 600 px.**
- **Fuentes con respaldo:** se pide Krona One / Figtree, pero Gmail no carga fuentes web, así
  que hay respaldos parecidos (Arial Black, Helvetica).
- **Logo en PNG por https** (si está configurado en Ajustes); los SVG no se ven en Gmail.
  Sin logo se muestra un cuadrito arena con la inicial.
- **Texto escapado** (`&`, `<`, `>`) para que el nombre de un cliente no rompa el HTML.
- **Siempre va una versión de texto plano** como alternativa, y el PDF adjunto.

## 5. Portal del cliente

El cliente ve la **misma identidad** que el realizador, para que sienta que entra al
espacio del negocio y no a otra app:

- Mismo `Lienzo`, `DockNav`, `TarjetaSuave`, `EtiquetaSeccion` y acento arena.
- 4 pestañas: **Inicio** (quién eres, próximo rodaje, lo pendiente), **Cotizaciones**
  (lista y detalle, con *Aceptar* en arena y *Pedir cambios* secundario), **Solicitar**
  (solo el tipo es obligatorio, para no frenar al cliente) y **Novedades** (el Inicio del
  cliente avisa cuántas novedades no ha leído).
- El cliente **no edita**: no hay campos de precio ni estados; solo respuestas.
- Estados de carga, vacío y error con los mismos componentes (`Vacio`, `Aviso`); probados a
  390 × 844 en `test/portal_cliente_test.dart`.
- Entrada con código: campo grande (22 px, mayúsculas automáticas, letras espaciadas) para
  `CLQ-XXXXXX`; el código no usa caracteres que se confunden (0/O, 1/I/L).

## Decisiones de diseño (y por qué)

- **Un solo acento (arena):** guía la vista a la acción principal. Fue observación del
  profesor de Procesos App: fondo calmado y botones principales legibles.
- **Un solo estilo en todas las pantallas:** antes convivían dos lenguajes (tarjetas hero
  con degradado y tarjetas oscuras). Unificar en el estilo del Home reduce ruido y hace que
  cada pantalla se entienda igual.
- **Pocos botones por pantalla:** el usuario cotiza desde el celular, a veces en rodaje.
- **Sin desenfoque ni animación de fondo:** mejor rendimiento en celulares modestos y más
  contraste de lectura. (El estilo "vidrio" anterior está en `lib/vidrio.dart`, sin uso.)
- **Figtree para títulos de pantalla y Krona One para marca y cifras:** igual que el saludo
  del Home; Krona One queda como voz de marca y no compite con el contenido.
- **Correo con la identidad del portafolio:** la cotización es la primera pieza que ve el
  cliente; que se vea como el resto de la marca refuerza el profesionalismo.
- Referentes: apps de tareas y de billetera (navegación en píldora, cifras grandes,
  gráficas en cápsula).

## Ícono y nombre (en curso)

Se está agregando un ícono propio (claqueta arena sobre degradado petróleo) y el nombre
"Claqueta" en el teléfono. Cuando quede listo, documentar aquí los archivos de origen.
