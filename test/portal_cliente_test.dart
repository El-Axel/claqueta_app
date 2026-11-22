// Prueba de widgets del ESPACIO DEL CLIENTE (portal).
//
// Llena el `portal` a mano con datos de ejemplo (sin Supabase: no se
// llama cargar()) y comprueba que PrincipalCliente se dibuja a tamaño
// de teléfono (390 x 844) sin desbordes ni excepciones, que cada
// pestaña abre y que los detalles de cotización y rodaje se muestran.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claqueta/modelos.dart';
import 'package:claqueta/servicios/portal_cliente.dart';
import 'package:claqueta/tema.dart';
import 'package:claqueta/pantallas/cliente/codigo_cliente.dart';
import 'package:claqueta/pantallas/cliente/cotizaciones_cliente.dart';
import 'package:claqueta/pantallas/cliente/inicio_cliente.dart';
import 'package:claqueta/pantallas/cliente/piezas_cliente.dart';
import 'package:claqueta/pantallas/cliente/principal_cliente.dart';
import 'package:claqueta/pantallas/cliente/rodaje_cliente.dart';
import 'package:claqueta/pantallas/cliente/solicitar_cliente.dart';

void llenarPortal() {
  final hoy = DateTime.now();
  final ahoraUtc = DateTime.now().toUtc();
  portal
    ..realizadorId = '00000000-0000-0000-0000-000000000001'
    ..clienteId = 7
    ..nombreCliente = 'Laura Restrepo'
    ..negocio = 'Estudio La Toma'
    ..cargando = false
    ..error = null
    ..cotizaciones = [
      Cotizacion(
        n: 12,
        clienteId: 7,
        proyecto: 'Video institucional para la fundación',
        estado: estEnviada,
        items: [
          ItemCot(descripcion: 'Jornada de rodaje', unidad: 'día', precio: 1200000, cantidad: 2),
          ItemCot(descripcion: 'Edición y color', precio: 800000, cantidad: 1),
        ],
        descuento: 10,
        iva: true,
        creada: hoy.subtract(const Duration(days: 3)),
        enviada: hoy.subtract(const Duration(days: 2)),
      ),
      Cotizacion(
        n: 11,
        clienteId: 7,
        proyecto: 'Fotos de producto',
        estado: estEnviada,
        items: [ItemCot(descripcion: 'Sesión de fotos', precio: 600000, cantidad: 1)],
        creada: hoy.subtract(const Duration(days: 6)),
      ),
      Cotizacion(
        n: 9,
        clienteId: 7,
        proyecto: 'Lanzamiento de marca',
        estado: estAceptada,
        items: [ItemCot(descripcion: 'Cubrimiento de evento', precio: 1500000, cantidad: 1)],
        creada: hoy.subtract(const Duration(days: 30)),
      ),
      Cotizacion(
        n: 8,
        clienteId: 7,
        proyecto: 'Videoclip',
        estado: estRechazada,
        items: [ItemCot(descripcion: 'Videoclip completo', precio: 3000000, cantidad: 1)],
        creada: hoy.subtract(const Duration(days: 60)),
      ),
    ]
    ..trabajos = [
      // Lugares sin coordenadas: se usa el mapa dibujado (sin red en pruebas).
      Trabajo(
        id: 1,
        cotN: 9,
        clienteId: 7,
        titulo: 'Lanzamiento de marca',
        fecha: hoy.add(const Duration(days: 4)),
        hora: '15:00',
        lugar: 'Hotel Dann Carlton',
        zona: 'El Poblado',
        valor: 1500000,
        pagos: [
          Pago(tipo: 'Anticipo', monto: 750000, metodo: 'Transferencia', fecha: hoy),
        ],
      ),
      Trabajo(
        id: 2,
        clienteId: 7,
        titulo: 'Entrevistas de archivo',
        fecha: hoy.subtract(const Duration(days: 20)),
        hora: '09:00',
        lugar: 'Oficina principal',
        valor: 900000,
        pagos: [
          Pago(tipo: 'Pago total', monto: 900000, metodo: 'Efectivo', fecha: hoy),
        ],
      ),
    ]
    ..solicitudes = [
      {
        'id': 1,
        'tipo': 'Redes sociales',
        'descripcion': 'Tres reels para el mes de diciembre',
        'fecha_tentativa': '2026-12-10',
        'lugar': 'Medellín',
        'estado': 'En cotización',
        'creada': ahoraUtc.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 2,
        'tipo': 'Evento',
        'descripcion': null,
        'fecha_tentativa': null,
        'lugar': null,
        'estado': 'Nueva',
        'creada': ahoraUtc.toIso8601String(),
      },
    ]
    ..respuestas = [
      {
        'id': 1,
        'cot_n': 11,
        'accion': 'cambios',
        'mensaje': '¿Pueden ser 20 fotos en vez de 10?',
        'procesada': false,
        'creada': ahoraUtc.toIso8601String(),
      },
    ]
    ..novedades = [
      {
        'id': 3,
        'tipo': 'pago',
        'texto': 'Registramos tu anticipo de \$750.000.',
        'creada': ahoraUtc.toIso8601String(),
      },
      {
        'id': 2,
        'tipo': 'rodaje',
        'texto': 'Agendamos el rodaje "Lanzamiento de marca".',
        'creada': ahoraUtc.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 1,
        'tipo': 'cotizacion',
        'texto': 'Te enviamos la cotización COT-0012.',
        'creada': ahoraUtc.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
}

Future<void> montar(WidgetTester t, Widget pantalla) async {
  await t.pumpWidget(MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: crearTema(),
    home: pantalla,
  ));
  await esperar(t);
}

Future<void> esperar(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

/// Desplaza la lista visible hasta que aparezca `f` (las listas se
/// construyen a medida que se ven: lo de abajo no existe hasta bajar).
/// `dentroDe` elige la lista de una pestaña (el IndexedStack mantiene
/// vivas las otras); sin él se usa la primera lista de la pantalla.
Future<void> verAbajo(WidgetTester t, Finder f, {Finder? dentroDe}) => t.scrollUntilVisible(
      f,
      250,
      scrollable: (dentroDe == null
              ? find.byType(Scrollable)
              : find.descendant(of: dentroDe, matching: find.byType(Scrollable)))
          .first,
      maxScrolls: 40,
    );

void main() {
  final errores = <String>[];
  FlutterExceptionHandler? errorOriginal; // se restaura al terminar cada prueba

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    llenarPortal();
    pestanaCliente.value = 0;
    errores.clear();
    errorOriginal = FlutterError.onError;
    FlutterError.onError = (d) {
      final txt = d.exceptionAsString();
      // Las fuentes de Google no se descargan en pruebas: se ignora ese aviso.
      if (txt.contains('GoogleFonts') || txt.contains('google_fonts')) return;
      errores.add(txt);
    };
  });

  tearDown(() => FlutterError.onError = errorOriginal);

  void aTelefono(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('PrincipalCliente: cada pestaña abre sin desbordes ni errores', (t) async {
    aTelefono(t);
    await montar(t, const PrincipalCliente());

    // Inicio
    expect(find.text('Hola, Laura'), findsOneWidget);
    expect(find.text('Tu realizador: Estudio La Toma'), findsOneWidget);
    expect(find.text('Lanzamiento de marca'), findsWidgets);
    // Contador de novedades sin leer sobre el dock.
    expect(find.text('3'), findsOneWidget);

    // Cotizaciones
    await t.tap(find.byIcon(Icons.description_outlined).last);
    await esperar(t);
    expect(pestanaCliente.value, 1);
    expect(find.text('Cotizaciones'), findsWidgets);
    expect(find.text('Video institucional para la fundación'), findsWidgets);

    // Solicitar
    await t.tap(find.byIcon(Icons.add_circle_outline));
    await esperar(t);
    expect(pestanaCliente.value, 2);
    expect(find.text('Enviar solicitud'), findsOneWidget);
    final solicitar = find.byType(PestanaSolicitarCliente);
    await verAbajo(t, find.text('MIS SOLICITUDES'), dentroDe: solicitar);
    await verAbajo(t, find.text('En cotización'), dentroDe: solicitar);
    expect(find.text('En cotización'), findsOneWidget);

    // Novedades: al entrar quedan como vistas (el contador desaparece).
    await t.tap(find.byIcon(Icons.notifications_none_rounded));
    await esperar(t);
    expect(pestanaCliente.value, 3);
    expect(portal.noLeidas, 0);
    expect(find.text('3 novedades nuevas'), findsOneWidget);
    expect(find.text('Registramos tu anticipo de \$750.000.'), findsOneWidget);

    // Volver a Inicio
    await t.tap(find.byIcon(Icons.home_outlined));
    await esperar(t);
    expect(pestanaCliente.value, 0);

    // El servicio de clima (sin red en pruebas) agenda un reintento a los
    // 2 minutos: se deja correr ese temporizador antes de terminar.
    await t.pump(const Duration(minutes: 3));

    final otro = t.takeException();
    if (otro != null) errores.add(otro.toString());
    expect(errores, isEmpty, reason: errores.join('\n'));
  });

  testWidgets('Detalles de cotización y de rodaje se dibujan bien', (t) async {
    aTelefono(t);
    final casos = <String, Widget>{
      'Enviada': const DetalleCotizacionCliente(12),
      'Con respuesta pendiente': const DetalleCotizacionCliente(11),
      'Aceptada': const DetalleCotizacionCliente(9),
      'Rechazada': const DetalleCotizacionCliente(8),
      'Inexistente': const DetalleCotizacionCliente(99),
      'Rodaje': const DetalleRodajeCliente(1),
      'Historial': const PantallaHistorialCliente(),
      'Código': const PantallaCodigoCliente(),
    };
    for (final c in casos.entries) {
      errores.clear();
      await montar(t, c.value);
      final otro = t.takeException();
      if (otro != null) errores.add(otro.toString());
      expect(errores, isEmpty, reason: '${c.key}: ${errores.join('\n')}');
    }

    await montar(t, const DetalleCotizacionCliente(12));
    await verAbajo(t, find.text('Pedir cambios'));
    expect(find.text('Aceptar cotización'), findsOneWidget);
    // "Pedir cambios" abre la hoja; sin mensaje no deja enviar.
    await t.tap(find.text('Pedir cambios'));
    await esperar(t);
    expect(find.text('Enviar cambios'), findsOneWidget);

    await montar(t, const DetalleCotizacionCliente(11));
    await verAbajo(t, find.text('Respuesta enviada · esperando a Estudio La Toma'));
    expect(find.text('Aceptar cotización'), findsNothing);

    await montar(t, const DetalleCotizacionCliente(9));
    await verAbajo(t, find.text('TU RODAJE'));
    expect(find.text('Aceptada ✓'), findsOneWidget);

    await t.pump(const Duration(minutes: 3)); // reintento del clima (ver arriba)
    final otro = t.takeException();
    if (otro != null) errores.add(otro.toString());
    expect(errores, isEmpty, reason: errores.join('\n'));
  });

  testWidgets('Estados vacío, de carga y de error', (t) async {
    aTelefono(t);
    portal
      ..cotizaciones = []
      ..trabajos = []
      ..solicitudes = []
      ..respuestas = []
      ..novedades = []
      ..error = 'No se pudo actualizar. Revisa tu conexión.';
    await montar(t, const PrincipalCliente());
    expect(find.text('Sin rodajes agendados'), findsOneWidget);
    expect(find.textContaining('Toca para reintentar'), findsOneWidget);
    for (final icono in [
      Icons.description_outlined,
      Icons.add_circle_outline,
      Icons.notifications_none_rounded,
    ]) {
      await t.tap(find.byIcon(icono).last);
      await esperar(t);
    }
    expect(find.text('Sin novedades'), findsOneWidget);

    portal
      ..error = null
      ..cargando = true;
    pestanaCliente.value = 0;
    await montar(t, const PrincipalCliente());
    expect(find.text('Cargando tu espacio…'), findsOneWidget);
    portal.cargando = false;

    await t.pump(const Duration(minutes: 3)); // reintento del clima (ver arriba)
    final otro = t.takeException();
    if (otro != null) errores.add(otro.toString());
    expect(errores, isEmpty, reason: errores.join('\n'));
  });

  test('fechaRelativa', () {
    final ahora = DateTime(2026, 11, 21, 10);
    expect(fechaRelativa(DateTime(2026, 11, 21, 9, 5), ahora: ahora), 'hoy, 9:05 am');
    expect(fechaRelativa(DateTime(2026, 11, 20, 23), ahora: ahora), 'ayer');
    expect(fechaRelativa(DateTime(2026, 11, 18), ahora: ahora), 'hace 3 días');
  });
}
