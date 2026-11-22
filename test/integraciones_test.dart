import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:claqueta/modelos.dart';
import 'package:claqueta/servicios/correo_html.dart';
import 'package:claqueta/servicios/google_api.dart';
import 'package:claqueta/servicios/lugares_api.dart';
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
