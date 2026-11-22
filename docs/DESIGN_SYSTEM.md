# Design System — Claqueta

Todo vive en dos archivos, así que cambiar un color o una fuente se hace en un solo lugar.

## `lib/tema.dart` (tokens)

| Token | Valor | Uso |
|---|---|---|
| `Paleta.suelo` | `#0B1315` | Fondo de la app |
| `Paleta.panel` / `panel2` | `#132126` / `#1A2C32` | Superficies |
| `Paleta.petroleo` | `#2A5159` | Profundidad, resaltes |
| `Paleta.teal` | `#2EA690` | Color de marca; estados y gráficas secundarias |
| `Paleta.arena` | `#F2C572` | **Único acento**: botón principal, pestaña activa, chip elegido |
| `Paleta.durazno` / `terracota` | `#F29863` / `#D9674E` | Enviada / alertas y peligro |
| `Paleta.tinta` | `#F4F1EA` | Texto |

Tipografías (Google Fonts): **Krona One** para títulos y cifras grandes (`estiloDisplay`) y **Figtree** para el texto (`estiloSuave` y el `textTheme`).
`coloresEstado` asigna un color a cada estado de cotización. `crearTema()` arma el `ThemeData` oscuro con `primary = arena`.

## `lib/estilo.dart` y `lib/widgets.dart` (componentes)

| Componente | Para qué |
|---|---|
| `Lienzo` + `FondoVivo` | Pantalla con fondo oscuro, bruma teal y grano |
| `Panel` | Tarjeta oscura con borde fino (base de todo) |
| `TarjetaHero` | Tarjeta con degradado teal → arena y texto oscuro |
| `BotonClaqueta` | Píldora: primario (arena), secundario, peligro |
| `DockNav` | Navegación inferior: la pestaña activa se expande |
| `AccionRapida`, `PildoraOscura`, `BotonPildora`, `BotonCirculo` | Acciones y chips |
| `BarraBrillante`, `Ficha`, `Estadisticas` | Progreso, inicial en cuadrito, cifras |
| `Etiqueta`, `TituloSeccion`, `FilaItem`, `FilaCot`, `FilaTrabajo`, `Vacio`, `Aviso` | Listas y estados |
| `decoracionCampo`, `hojaInferior`, `confirmar`, `barra` | Formularios, hojas, diálogos y barra superior |

## Decisiones de diseño (y por qué)

- **Un solo acento** (arena): guía la vista hacia la acción principal. Fue observación del profesor de Procesos App: fondo calmado y botones principales legibles.
- **Pocos botones por pantalla:** el usuario es un realizador freelance que cotiza desde el celular, a veces en rodaje.
- **Tarjetas oscuras sin desenfoque:** mejor rendimiento en celulares modestos y más contraste de lectura.
- Referentes: apps de tareas y de billetera con tarjeta hero en degradado, navegación en píldora y gráficas en cápsula.
