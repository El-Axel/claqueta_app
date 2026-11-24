import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:claqueta/modelos.dart';
import 'package:claqueta/servicios/captcha.dart';
import 'package:claqueta/servicios/correo_html.dart';
import 'package:claqueta/servicios/google_api.dart';
import 'package:claqueta/servicios/lugares_api.dart';
import 'package:claqueta/servicios/nube.dart';
import 'package:claqueta/servicios/portal_cliente.dart' show mensajeCanje;
import 'package:claqueta/tienda.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:claqueta/util.dart';

// Pruebas de las integraciones que no necesitan internet.
void main() {
  test('El correo MIME lleva destinatario, asunto en UTF-8 y el PDF adjunto', () {
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 prueba'));
    final mime = construirMime(
      para: 'cliente@ejemplo.com',
      asunto: 'Cotización COT-0001',
      cuerpo: 'Hola, te comparto la cotización.',
      pdf: pdf,
      nombrePdf: 'COT-0001.pdf',
    );
    expect(mime, contains('To: cliente@ejemplo.com'));
    expect(mime, contains('=?UTF-8?B?${base64.encode(utf8.encode('Cotización COT-0001'))}?='));
    expect(mime, contains('multipart/mixed'));
    expect(mime, contains('filename="COT-0001.pdf"'));
    expect(mime, contains(base64.encode(pdf)));
  });

  test('El correo con diseño lleva texto y HTML como alternativas, y escapa el texto', () {
    final c = Cotizacion(
      n: 44, clienteId: 1, proyecto: 'Video <promo>', creada: DateTime(2026, 11, 22),
      items: [ItemCot(descripcion: 'Cámara cine', precio: 450000, cantidad: 1)],
    );
    final cl = Cliente(id: 1, nombre: 'Ana & Co', correo: 'ana@ejemplo.com', telefono: '');
    final html = correoCotizacionHtml(
        c: c, cl: cl, cfg: Config(), remitente: 'yo@ejemplo.com');
    expect(html, contains('COT-0044'));
    expect(html, contains('Ana &amp; Co'));
    expect(html, contains('Video &lt;promo&gt;'));
    expect(html, isNot(contains('<promo>')));
    expect(html, contains(formatearPesos(c.total)));
    final mime = construirMime(
        para: cl.correo, asunto: 'x', cuerpo: 'texto', html: html,
        pdf: Uint8List.fromList([1, 2, 3]));
    expect(mime, contains('multipart/alternative'));
    expect(mime, contains('text/html'));
    expect(mime, contains('application/pdf'));
  });

  test('Las filas para Supabase llevan dueño, relaciones y el objeto completo', () {
    final j = {
      'config': Config().toJson(),
      'clientes': [Cliente(id: 1, nombre: 'Ana', correo: 'a@x.co', telefono: '').toJson()],
      'servicios': <Map<String, dynamic>>[],
      'paquetes': <Map<String, dynamic>>[],
      'cotizaciones': [
        Cotizacion(
          n: 7, clienteId: 1, proyecto: 'Video', creada: DateTime(2026, 11, 22), descuento: 10, iva: true,
          items: [ItemCot(descripcion: 'Cámara', precio: 100000, cantidad: 2)],
        ).toJson()
      ],
      'trabajos': <Map<String, dynamic>>[],
    };
    final f = filasParaSubir(j, 'uid-123');
    final cot = f['cotizaciones']!.single;
    expect(cot['user_id'], 'uid-123');
    expect(cot['cliente_id'], 1);
    // 200.000 - 10 % = 180.000; + IVA 19 % = 214.200
    expect(cot['total'], 214200);
    expect((cot['datos'] as Map)['proyecto'], 'Video');
    expect(f['clientes']!.single['nombre'], 'Ana');
    expect(f['config']!.single['user_id'], 'uid-123');
  });

  test('Un usuario nuevo empieza vacío; los ejemplos se cargan a mano', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final t = Tienda();
    await t.cargar();
    expect(t.estaVacia, isTrue);
    expect(t.config.negocio, 'Mi negocio');
    expect(t.config.web, isEmpty);
    t.config.negocio = 'Estudio X';
    t.cargarEjemplos();
    expect(t.clientes, isNotEmpty);
    expect(t.config.negocio, 'Estudio X'); // los ajustes del negocio se conservan
    expect(t.clientes.every((c) => c.codigo.startsWith('CLQ-')), isTrue);
    t.borrarTodo();
    expect(t.estaVacia, isTrue);
  });

  test('Si entra otra cuenta, el teléfono se vacía sin tocar la nube', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final t = Tienda();
    await t.cargar();
    var subidas = 0;
    t.alGuardar = () => subidas++;
    t.cargarEjemplos();
    t.fijarDueno('cuenta-A');
    final antes = subidas;
    t.vaciarLocal();
    expect(t.estaVacia, isTrue);
    expect(subidas, antes); // no programa subida: no borra la nube
    expect(t.dueno, 'cuenta-A');
  });

  test('El límite de intentos del código se explica al cliente', () {
    expect(mensajeCanje({'realizador_id': 'x', 'cliente_id': 1}), isNull);
    expect(mensajeCanje({'error': 'no_valido', 'restantes': 4}), contains('no existe'));
    expect(mensajeCanje({'error': 'no_valido', 'restantes': 1}), contains('1 intento'));
    expect(mensajeCanje({'error': 'bloqueado', 'espera_min': 15}), contains('15 minutos'));
  });

  test('Cambiar el código da uno nuevo, distinto y con el formato correcto', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final t = Tienda();
    await t.cargar();
    t.cargarEjemplos();
    final c = t.clientes.first;
    final viejo = c.codigo;
    t.cambiarCodigo(c.id);
    expect(c.codigo, isNot(viejo));
    expect(RegExp(r'^CLQ-[A-Z2-9]{6}$').hasMatch(c.codigo), isTrue);
  });

  test('Sin clave de Turnstile el CAPTCHA queda apagado y no estorba', () async {
    expect(captchaActivo, isFalse);
    expect(await tokenCaptcha(), isNull);
  });

  test('Los errores de la cuenta se explican en español', () {
    expect(mensajeAuth(const AuthException('Invalid login credentials', code: 'invalid_credentials')),
        'Correo o contraseña incorrectos');
    expect(mensajeAuth(const AuthException('User already registered', code: 'user_already_exists')),
        contains('Ya existe una cuenta'));
    expect(mensajeAuth(const AuthException('Password should be at least 6 characters', code: 'weak_password')),
        contains('6 caracteres'));
  });

  test('Solo se piden los permisos mínimos de Google', () {
    expect(scopesGoogle, [
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/calendar.events',
    ]);
  });

  test('Los lugares de ejemplo tienen coordenadas para el mapa y el clima', () {
    final t = Trabajo(
        id: 1, clienteId: 1, titulo: 'x', fecha: DateTime(2026, 11, 23),
        hora: '14:00', lugar: 'Parque Lleras', valor: 0);
    final c = coordenadasTrabajo(t);
    expect(c, isNotNull);
    expect(c!.$1, closeTo(6.2, 0.1));
  });

  test('La distancia Pereira–Medellín es de unos 170 km en línea recta', () {
    const pereira = (4.8133, -75.6961);
    const medellin = (6.2476, -75.5658);
    expect(distanciaKm(pereira, medellin), closeTo(160, 15));
    expect(textoDistancia(0.85), '850 m');
    expect(textoDistancia(12.4), '12 km');
  });

  test('Trabajo guarda y recupera coordenadas y evento de Calendar', () {
    final t = Trabajo(
        id: 1, clienteId: 1, titulo: 'x', fecha: DateTime(2026, 11, 23),
        hora: '14:00', lugar: 'Calle 10', lat: 6.2, lon: -75.5, valor: 0, eventoId: 'abc');
    final copia = Trabajo.fromJson(t.toJson());
    expect(copia.lat, 6.2);
    expect(copia.lon, -75.5);
    expect(copia.eventoId, 'abc');
  });
}
