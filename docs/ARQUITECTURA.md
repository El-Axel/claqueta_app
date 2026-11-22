# Arquitectura — Claqueta

```
lib/
  main.dart            arranque: carga datos y decide Entrada o Principal
  tema.dart            Design System: colores y tipografías
  estilo.dart          Design System: fondo, nav y componentes visuales
  widgets.dart         componentes de lista, botones, campos, hojas
  modelos.dart         datos: Cliente, Servicio, Paquete, Cotizacion, Trabajo, Pago, Config
  tienda.dart          estado y lógica (ChangeNotifier) + persistencia
  util.dart            formato de pesos y fechas, clima simulado, lugares de ejemplo
  compartir.dart       mensajes, WhatsApp y correo
  pdf_documentos.dart  generación de PDF
  selectores.dart      selector de cliente
  pantallas/           una archivo por pantalla (17)
test/logica_test.dart  pruebas de totales, pagos y formato
```

**Patrón:** estado único en `Tienda` (`ChangeNotifier`), las pantallas lo escuchan con
`ListenableBuilder`. Sin paquetes de estado externos: es lo visto en clase y se puede explicar completo.

**Por qué así:** los modelos no saben nada de la interfaz; la lógica de negocio (totales, cruces,
finanzas, seguimiento) está en un solo lugar y se prueba sin abrir la app; las pantallas solo
dibujan y llaman a la tienda.

**Persistencia:** `SharedPreferences`, un JSON bajo la clave `claqueta-v2`. Exportar y restaurar usan
ese mismo JSON.

**Navegación:** `IndexedStack` con 5 pestañas (Inicio, Cotizar, Agenda, Finanzas, Clientes) y
`Navigator.push` para el resto. Una pestaña activa global (`pestana`) permite saltar de una a otra.

**Paquetes:** `google_fonts`, `shared_preferences`, `pdf`, `printing`, `url_launcher`.
