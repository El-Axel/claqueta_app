// Prueba "clic por clic" de toda la app (evidencia de pruebas).
//
// Para cada pantalla: encuentra todos los elementos tocables, los pulsa
// uno por uno (reiniciando los datos de ejemplo antes de cada toque) y
// anota qué pasó: a qué pantalla llevó, si abrió un diálogo, si no hubo
// cambio visible o si lanzó un error. Además dibuja cada pantalla a
// tamaño de teléfono (390 x 844) para detectar desbordes de diseño.
//
// Ejecutar:  flutter test test/recorrido_clics_test.dart
// Informe:   docs/PRUEBA_CLICS.md
//
// Limitaciones (para decirlas en la sustentación):
// - Las pruebas usan una fuente de prueba (no Figtree/Krona One), así que
//   un desborde aquí es un candidato a revisar en el emulador, no un hecho.
// - Los plugins nativos (compartir PDF, imprimir, abrir Gmail/WhatsApp)
//   no existen en el entorno de prueba; esos casos se marcan aparte.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claqueta/tema.dart';
import 'package:claqueta/tienda.dart';
import 'package:claqueta/pantallas/agendar_trabajo.dart';
import 'package:claqueta/pantallas/ajustes.dart';
import 'package:claqueta/pantallas/catalogo.dart';
import 'package:claqueta/pantallas/detalle_cliente.dart';
import 'package:claqueta/pantallas/detalle_cotizacion.dart';
import 'package:claqueta/pantallas/detalle_trabajo.dart';
import 'package:claqueta/pantallas/entrada.dart';
import 'package:claqueta/pantallas/envio_cotizacion.dart';
import 'package:claqueta/pantallas/formulario_cliente.dart';
import 'package:claqueta/pantallas/nueva_cotizacion.dart';
import 'package:claqueta/pantallas/pdf_vista.dart';
import 'package:claqueta/pantallas/principal.dart';

// ---------- Pantallas a recorrer ----------
class Caso {
  final String nombre;
  final bool sesion;
  final int pestana;
  final Widget Function() crear;
  Caso(this.nombre, this.crear, {this.sesion = true, this.pestana = 0});
}

List<Caso> casos() => [
      Caso('Entrada', () => const PantallaEntrada(), sesion: false),
      Caso('Conectar con Google', () => const PantallaGoogle(), sesion: false),
      Caso('Inicio', () => const PantallaPrincipal(), pestana: 0),
      Caso('Cotizar', () => const PantallaPrincipal(), pestana: 1),
      Caso('Agenda', () => const PantallaPrincipal(), pestana: 2),
      Caso('Finanzas', () => const PantallaPrincipal(), pestana: 3),
      Caso('Clientes', () => const PantallaPrincipal(), pestana: 4),
      Caso('Nueva cotización', () => const NuevaCotizacion()),
      Caso('Detalle de cotización',
          () => DetalleCotizacion(tienda.cotizaciones.first.n)),
      Caso('Envío', () => EnvioCotizacion(tienda.cotizaciones.first.n)),
      Caso('Catálogo y paquetes', () => const PantallaCatalogo()),
      Caso('Formulario de paquete', () => const FormularioPaquete()),
      Caso('Agendar trabajo', () => const PantallaAgendar()),
      Caso('Detalle de trabajo', () => DetalleTrabajo(tienda.trabajos.first.id)),
      Caso('Detalle de cliente', () => DetalleCliente(tienda.clientes.first.id)),
      Caso('Formulario de cliente', () => const FormularioCliente()),
      Caso('Ajustes', () => const PantallaAjustes()),
    ];

// Tipos que identifican "en qué pantalla estoy".
final Map<Type, String> tiposPantalla = {
  PantallaEntrada: 'Entrada',
  PantallaGoogle: 'Conectar con Google',
  PantallaPrincipal: 'Principal',
  NuevaCotizacion: 'Nueva cotización',
  DetalleCotizacion: 'Detalle de cotización',
  EnvioCotizacion: 'Envío',
  PdfVista: 'Vista de PDF',
  PantallaCatalogo: 'Catálogo',
  FormularioPaquete: 'Formulario de paquete',
  PantallaAgendar: 'Agendar trabajo',
  DetalleTrabajo: 'Detalle de trabajo',
  DetalleCliente: 'Detalle de cliente',
  FormularioCliente: 'Formulario de cliente',
  PantallaAjustes: 'Ajustes',
};
const nombresPestana = ['Inicio', 'Cotizar', 'Agenda', 'Finanzas', 'Clientes'];

// ---------- Utilidades ----------
final List<String> errores = [];

Future<void> montar(WidgetTester t, Caso c) async {
  tienda.cargarEjemplos();
  tienda.sesion = c.sesion;
  pestana.value = c.pestana;
  await t.pumpWidget(MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: crearTema(),
    home: c.crear(),
  ));
  await esperar(t);
}

Future<void> esperar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

bool _tieneToque(Widget w) =>
    (w is InkResponse && (w.onTap != null || w.onLongPress != null)) ||
    (w is GestureDetector && w.onTap != null) ||
    (w is Switch && w.onChanged != null) ||
    (w is Checkbox && w.onChanged != null) ||
    (w is EditableText);

/// Elementos tocables visibles, sin duplicados (un botón Material contiene
/// un InkWell y un GestureDetector en el mismo sitio: se cuenta una vez).
List<Element> tocables(WidgetTester t) {
  final todos =
      find.byWidgetPredicate(_tieneToque).hitTestable().evaluate().toList();
  final vistos = <String>{};
  final res = <Element>[];
  for (final e in todos) {
    final r = e.renderObject;
    if (r is! RenderBox || !r.hasSize) continue;
    final o = r.localToGlobal(Offset.zero);
    final clave =
        '${o.dx.round()},${o.dy.round()},${r.size.width.round()},${r.size.height.round()}';
    if (vistos.add(clave)) res.add(e);
  }
  res.sort((a, b) {
    final pa = (a.renderObject as RenderBox).localToGlobal(Offset.zero);
    final pb = (b.renderObject as RenderBox).localToGlobal(Offset.zero);
    final dy = pa.dy.compareTo(pb.dy);
    return dy != 0 ? dy : pa.dx.compareTo(pb.dx);
  });
  return res;
}

/// Nombre legible del elemento: sus textos, tooltip o icono.
String etiqueta(Element e) {
  final textos = <String>[];
  String? icono;
  void visitar(Element x) {
    final w = x.widget;
    if (w is Text && w.data != null) textos.add(w.data!);
    if (w is Text && w.data == null && w.textSpan != null) {
      textos.add(w.textSpan!.toPlainText());
    }
    if (w is EditableText && textos.isEmpty) textos.add('[campo de texto]');
    if (w is Icon && w.icon != null && icono == null) {
      icono = 'icono 0x${w.icon!.codePoint.toRadixString(16)}';
    }
    x.visitChildren(visitar);
  }

  visitar(e);
  String? tooltip;
  e.visitAncestorElements((a) {
    if (a.widget is Tooltip) {
      tooltip = (a.widget as Tooltip).message;
      return false;
    }
    return a.widget is! Scaffold;
  });
  if (e.widget is Switch) textos.insert(0, '[interruptor]');
  final base = textos.isNotEmpty
      ? textos.take(3).join(' · ')
      : (tooltip ?? icono ?? e.widget.runtimeType.toString());
  final limpio = base.replaceAll('\n', ' ').replaceAll('|', '/');
  return limpio.length > 70 ? '${limpio.substring(0, 67)}...' : limpio;
}

/// Pantalla visible arriba del todo + diálogos/hojas abiertos.
String dondeEstoy(WidgetTester t) {
  String? pantalla;
  for (final entrada in tiposPantalla.entries) {
    if (find.byType(entrada.key).evaluate().isNotEmpty) {
      pantalla = entrada.value;
    }
  }
  // La pantalla de más arriba en la pila es la última montada; si hay
  // varias visibles (ruta no opaca), se elige la más profunda del árbol.
  final rutas = <String>[];
  for (final entrada in tiposPantalla.entries) {
    for (final e in find.byType(entrada.key).evaluate()) {
      rutas.add('${_profundidad(e).toString().padLeft(5, '0')}${entrada.value}');
    }
  }
  if (rutas.isNotEmpty) {
    rutas.sort();
    pantalla = rutas.last.substring(5);
  }
  if (pantalla == 'Principal') {
    pantalla = 'Pestaña ${nombresPestana[pestana.value]}';
  }
  final extras = <String>[];
  if (find.byType(Dialog).evaluate().isNotEmpty ||
      find.byType(AlertDialog).evaluate().isNotEmpty) {
    extras.add('diálogo');
  }
  if (find.byType(DatePickerDialog).evaluate().isNotEmpty) {
    extras.add('selector de fecha');
  }
  if (find.byType(TimePickerDialog).evaluate().isNotEmpty) {
    extras.add('selector de hora');
  }
  if (find.byType(BottomSheet).evaluate().isNotEmpty) extras.add('hoja inferior');
  if (find.byType(SnackBar).evaluate().isNotEmpty) extras.add('aviso (snackbar)');
  return [pantalla ?? '?', ...extras].join(' + ');
}

int _profundidad(Element e) {
  var d = 0;
  e.visitAncestorElements((_) {
    d++;
    return true;
  });
  return d;
}

/// Firma del contenido visible para detectar "no pasó nada".
String firma(WidgetTester t) {
  final partes = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    partes.add(w.data ?? w.textSpan?.toPlainText() ?? '');
  }
  for (final e in find.byType(Switch).evaluate()) {
    partes.add('sw:${(e.widget as Switch).value}');
  }
  for (final e in find.byType(EditableText).evaluate()) {
    partes.add('foco:${(e.widget as EditableText).focusNode.hasFocus}');
  }
  return partes.join('|');
}

String resumirError(Object err) {
  final s = err.toString().split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => err.toString(),
      );
  final plugin = s.contains('MissingPluginException') ||
      s.contains('No implementation found');
  final linea = s.replaceAll('|', '/').trim();
  final corto = linea.length > 110 ? '${linea.substring(0, 107)}...' : linea;
  return plugin ? 'PLUGIN (solo en dispositivo): $corto' : 'ERROR: $corto';
}

// ---------- La prueba ----------
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await tienda.cargar();
  });

  testWidgets('Recorrido clic por clic de todas las pantallas', (t) async {
    final informe = StringBuffer();
    final resumen = <String, List<int>>{}; // pantalla -> [total, errores, sin cambio]
    final desbordes = <String>[];

    final errorOriginal = FlutterError.onError;
    FlutterError.onError = (d) {
      final txt = d.exceptionAsString();
      // Las fuentes de Google no se descargan en pruebas: se ignora ese aviso.
      if (txt.contains('GoogleFonts') || txt.contains('google_fonts')) return;
      errores.add(txt);
    };

    // 1) Desbordes a tamaño de teléfono, sin tocar nada.
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    for (final c in casos()) {
      errores.clear();
      await montar(t, c);
      final otro = t.takeException();
      if (otro != null) errores.add(otro.toString());
      for (final e in errores.where((e) => e.contains('overflowed'))) {
        desbordes.add('${c.nombre}: ${resumirError(e).replaceFirst('ERROR: ', '')}');
      }
    }

    // 2) Clics. Vista muy alta para que casi todo quepa sin hacer scroll.
    t.view.physicalSize = const Size(390, 2600);
    for (final c in casos()) {
      await montar(t, c);
      final n = tocables(t).length;
      var conError = 0, sinCambio = 0;
      informe.writeln('\n### ${c.nombre} ($n elementos tocables)\n');
      informe.writeln('| # | Elemento | Resultado |');
      informe.writeln('|---|---|---|');
      for (var i = 0; i < n; i++) {
        errores.clear();
        await montar(t, c);
        final lista = tocables(t);
        if (i >= lista.length) break;
        final el = lista[i];
        final nombre = etiqueta(el);
        final antesDonde = dondeEstoy(t);
        final antesFirma = firma(t);
        final centro = (el.renderObject as RenderBox)
            .localToGlobal((el.renderObject as RenderBox).size.center(Offset.zero));
        await t.tapAt(centro);
        await esperar(t);
        final ex = t.takeException();
        if (ex != null) errores.add(ex.toString());
        final despuesDonde = dondeEstoy(t);
        String resultado;
        final reales = errores
            .where((e) => !e.contains('overflowed'))
            .toList(); // desbordes ya se listan aparte
        if (reales.isNotEmpty) {
          resultado = resumirError(reales.first);
          if (!resultado.startsWith('PLUGIN')) conError++;
        } else if (despuesDonde != antesDonde) {
          resultado = '→ $despuesDonde';
        } else if (firma(t) != antesFirma) {
          resultado = 'cambia en la misma pantalla';
        } else {
          resultado = '⚠ sin cambio visible';
          sinCambio++;
        }
        informe.writeln('| ${i + 1} | $nombre | $resultado |');
        // Deja correr temporizadores (snackbars, animaciones) antes de seguir.
        await t.pump(const Duration(seconds: 5));
      }
      resumen[c.nombre] = [n, conError, sinCambio];
    }

    FlutterError.onError = errorOriginal;
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();

    // ---------- Informe ----------
    final out = StringBuffer()
      ..writeln('# Prueba clic por clic — Claqueta')
      ..writeln()
      ..writeln('Generado por `test/recorrido_clics_test.dart` el '
          '${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}.')
      ..writeln()
      ..writeln('Cada fila es un toque hecho por la prueba automática, empezando '
          'siempre desde los datos de ejemplo. «⚠ sin cambio visible» significa que '
          'el toque no cambió de pantalla ni de contenido: hay que revisarlo a mano '
          '(puede ser un campo de texto o un botón que no hace nada).')
      ..writeln()
      ..writeln('## Resumen')
      ..writeln()
      ..writeln('| Pantalla | Tocables | Errores | Sin cambio visible |')
      ..writeln('|---|---|---|---|');
    var tot = 0, totErr = 0, totSin = 0;
    resumen.forEach((k, v) {
      out.writeln('| $k | ${v[0]} | ${v[1]} | ${v[2]} |');
      tot += v[0];
      totErr += v[1];
      totSin += v[2];
    });
    out
      ..writeln('| **Total** | **$tot** | **$totErr** | **$totSin** |')
      ..writeln()
      ..writeln('## Desbordes a 390 × 844 (fuente de prueba: confirmar en emulador)')
      ..writeln();
    if (desbordes.isEmpty) {
      out.writeln('Ninguno.');
    } else {
      for (final d in desbordes) {
        out.writeln('- $d');
      }
    }
    out
      ..writeln()
      ..writeln('## Detalle por pantalla')
      ..write(informe);

    Directory('docs').createSync(recursive: true);
    File('docs/PRUEBA_CLICS.md').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print('Total: $tot toques, $totErr errores, $totSin sin cambio visible.');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
