import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../tienda.dart';
import 'lugares_api.dart';

// ---------------------------------------------------------------
// UBICACIÓN APROXIMADA del usuario.
// - Solo se pide la ubicación "aproximada" (nivel ciudad), no el GPS
//   exacto: basta para saber que estás en Pereira y es más privado.
// - Se usa para dos cosas: priorizar lugares cercanos al buscar
//   direcciones y dar el clima del Inicio de tu ciudad.
// - No sale del teléfono salvo para buscar el nombre de la ciudad en
//   OpenStreetMap; se guarda como "zona base" en Ajustes.
// ---------------------------------------------------------------

/// Pide permiso, toma la ubicación aproximada y la guarda como zona
/// base. Devuelve el nombre de la ciudad o lanza una excepción con un
/// mensaje en español.
Future<String> usarMiUbicacion() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Activa la ubicación del teléfono');
  }
  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.denied) {
    throw Exception('Sin permiso de ubicación. Puedes elegir la ciudad a mano.');
  }
  if (permiso == LocationPermission.deniedForever) {
    throw Exception('El permiso está bloqueado: actívalo en los ajustes del teléfono.');
  }
  // Se pide la ubicación ACTUAL (así, si viajas de Medellín a Bogotá,
  // la búsqueda cambia contigo). Si tarda, se usa la última conocida.
  Position? p;
  try {
    p = await Geolocator.getCurrentPosition(
      locationSettings: _ajustes(),
    );
  } catch (_) {
    p = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: !kIsWeb && Platform.isAndroid);
  }
  if (p == null) throw Exception('El teléfono no entregó la ubicación.');  // Claqueta busca lugares en Colombia: una ubicación fuera del país
  // (por ejemplo, la de California que traen los emuladores) no sirve.
  if (!enColombia(p.latitude, p.longitude)) {
    throw Exception('Tu ubicación aparece fuera de Colombia.');
  }
  final ciudad = await _nombreCiudad(p.latitude, p.longitude) ?? 'Mi ubicación';
  tienda.cambiarZona(ciudad, p.latitude, p.longitude);
  return ciudad;
}

/// En Android se usa el servicio de ubicación del sistema (no la copia
/// en caché de Google Play Services): responde al momento si cambias de
/// ciudad y funciona también en teléfonos sin servicios de Google.
LocationSettings _ajustes() {
  const limite = Duration(seconds: 10);
  if (!kIsWeb && Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: limite,
      forceLocationManager: true,
    );
  }
  return const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: limite);
}

/// ¿Las coordenadas caen dentro del recuadro de Colombia?
bool enColombia(double lat, double lon) =>
    lat > -4.3 && lat < 13.5 && lon > -79.2 && lon < -66.8;

/// Fija la zona escribiendo la ciudad (sin permiso de ubicación).
/// Devuelve el nombre guardado o lanza una excepción si no la encuentra.
Future<String> fijarCiudad(String nombre) async {
  final q = nombre.trim();
  if (q.isEmpty) throw Exception('Escribe una ciudad');
  final r = await buscarLugares('$q, Colombia');
  if (r.isEmpty) throw Exception('No encontré "$q". Revisa el nombre.');
  tienda.cambiarZona(q, r.first.lat!, r.first.lon!);
  return q;
}

/// Nombre de la ciudad para unas coordenadas (OpenStreetMap, sin clave).
Future<String?> _nombreCiudad(double lat, double lon) async {
  try {
    final r = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lon',
        'format': 'jsonv2',
        'zoom': '10',
        'accept-language': 'es',
      }),
      headers: {'User-Agent': 'Claqueta/1.0 (app academica Flutter)'},
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final dir = ((jsonDecode(r.body) as Map<String, dynamic>)['address'] ?? {})
        as Map<String, dynamic>;
    final n = (dir['city'] ?? dir['town'] ?? dir['village'] ?? dir['county']) as String?;
    return n == null ? null : limpiarNombre(n);
  } catch (_) {
    return null;
  }
}
