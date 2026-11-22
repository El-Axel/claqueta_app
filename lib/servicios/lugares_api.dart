import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../util.dart';

// ---------------------------------------------------------------
// BÚSQUEDA DE DIRECCIONES con OpenStreetMap (Nominatim).
// - Gratis y sin clave. Se eligió en lugar de Google Places/Maps
//   porque Google exige activar facturación en Google Cloud.
// - Reglas de uso de Nominatim: máximo 1 consulta por segundo e
//   identificarse con un User-Agent. Por eso la pantalla espera a
//   que dejes de escribir antes de buscar.
// ---------------------------------------------------------------

/// Busca lugares PRIORIZANDO la zona del usuario (cerca = lat, lon):
/// 1) primero solo dentro de un cuadro de ~30 km alrededor;
/// 2) si no hay nada, en toda Colombia.
/// Los resultados quedan ordenados del más cercano al más lejano.
Future<List<Lugar>> buscarLugares(String texto, {(double, double)? cerca}) async {
  final q = texto.trim();
  if (q.length < 3) return [];
  var lugares = <Lugar>[];
  if (cerca != null) {
    lugares = await _consultar(q, cerca: cerca);
  }
  if (lugares.isEmpty) lugares = await _consultar(q);
  if (cerca != null) {
    lugares.sort((a, b) => distanciaKm(cerca, (a.lat!, a.lon!))
        .compareTo(distanciaKm(cerca, (b.lat!, b.lon!))));
  }
  return lugares;
}

Future<List<Lugar>> _consultar(String q, {(double, double)? cerca}) async {
  const delta = 0.27; // ~30 km en grados cerca del ecuador
  final url = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': q,
    'format': 'jsonv2',
    'countrycodes': 'co',
    'limit': '6',
    'addressdetails': '1',
    'accept-language': 'es',
    if (cerca != null) ...{
      // viewbox = izquierda,arriba,derecha,abajo ; bounded=1 = solo dentro
      'viewbox':
          '${cerca.$2 - delta},${cerca.$1 + delta},${cerca.$2 + delta},${cerca.$1 - delta}',
      'bounded': '1',
    },
  });
  final r = await http.get(url, headers: {
    'User-Agent': 'Claqueta/1.0 (app academica Flutter)',
  }).timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
  final lista = jsonDecode(r.body) as List;
  return lista.map((e) {
    final m = e as Map<String, dynamic>;
    final dir = (m['address'] ?? {}) as Map<String, dynamic>;
    final nombre = (m['name'] as String?)?.isNotEmpty == true
        ? m['name'] as String
        : (m['display_name'] as String).split(',').first;
    final zona = limpiarNombre([
      dir['suburb'] ?? dir['neighbourhood'] ?? dir['quarter'],
      dir['city'] ?? dir['town'] ?? dir['village'] ?? dir['state'],
    ].whereType<String>().join(', '));
    return Lugar(
      nombre,
      zona,
      lat: double.parse(m['lat'] as String),
      lon: double.parse(m['lon'] as String),
    );
  }).toList();
}

/// OpenStreetMap nombra algunas ciudades como "Perímetro Urbano Medellín":
/// se deja solo "Medellín".
String limpiarNombre(String s) =>
    s.replaceAll(RegExp(r'Per[ií]metro Urbano\s+', caseSensitive: false), '').trim();

/// Distancia en km entre dos puntos (fórmula de Haversine).
double distanciaKm((double, double) a, (double, double) b) {
  const r = 6371.0;
  double rad(double g) => g * pi / 180;
  final dLat = rad(b.$1 - a.$1);
  final dLon = rad(b.$2 - a.$2);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(a.$1)) * cos(rad(b.$1)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(sqrt(h));
}

/// "850 m" o "12 km", para mostrar junto a cada resultado.
String textoDistancia(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

/// Enlace para abrir el punto en Google Maps (no necesita clave).
Uri enlaceGoogleMaps(double lat, double lon) => Uri.https(
    'www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lon'});
