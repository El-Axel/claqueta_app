import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../util.dart';

// ---------------------------------------------------------------
// CLIMA REAL con Open-Meteo (https://open-meteo.com).
// - Gratis, sin clave y sin facturación: no hay secretos en la app.
// - Da el pronóstico diario de los próximos 16 días para unas
//   coordenadas. Se guarda en memoria por ubicación.
// - Si no hay internet o la fecha está a más de 16 días, la app usa
//   un clima ESTIMADO (marcado así en pantalla), nunca inventa que
//   es real.
// ---------------------------------------------------------------

final ServicioClima servicioClima = ServicioClima();

class ServicioClima extends ChangeNotifier {
  // "lat,lon" redondeado -> "aaaa-mm-dd" -> Clima
  final Map<String, Map<String, Clima>> _pronosticos = {};
  final Set<String> _pedidos = {};

  /// Último error de red (para mostrarlo en Ajustes si hace falta).
  String? error;

  static String _claveLugar(double lat, double lon) =>
      '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  static String _claveDia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Devuelve el pronóstico real si ya está descargado. Si no, lo pide
  /// en segundo plano (y avisa a las pantallas cuando llega).
  Clima? pronostico(DateTime fecha, double lat, double lon) {
    final clave = _claveLugar(lat, lon);
    final datos = _pronosticos[clave];
    if (datos == null) {
      _descargar(lat, lon);
      return null;
    }
    return datos[_claveDia(fecha)];
  }

  Future<void> _descargar(double lat, double lon) async {
    final clave = _claveLugar(lat, lon);
    if (!_pedidos.add(clave)) return; // ya se pidió
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'daily':
          'weather_code,temperature_2m_max,precipitation_probability_max,wind_speed_10m_max',
      'timezone': 'America/Bogota',
      'forecast_days': '16',
    });
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final daily = (jsonDecode(r.body) as Map<String, dynamic>)['daily']
          as Map<String, dynamic>;
      final dias = (daily['time'] as List).cast<String>();
      final codigos = daily['weather_code'] as List;
      final temps = daily['temperature_2m_max'] as List;
      final lluvias = daily['precipitation_probability_max'] as List;
      final vientos = daily['wind_speed_10m_max'] as List;
      final mapa = <String, Clima>{};
      for (var i = 0; i < dias.length; i++) {
        final codigo = (codigos[i] as num?)?.toInt() ?? 0;
        final desc = _descripcion(codigo);
        mapa[dias[i]] = Clima(
          desc.$1,
          ((temps[i] as num?) ?? 0).round(),
          ((lluvias[i] as num?) ?? 0).round(),
          ((vientos[i] as num?) ?? 0).round(),
          desc.$2,
          real: true,
        );
      }
      _pronosticos[clave] = mapa;
      error = null;
      notifyListeners();
    } catch (e) {
      error = 'No se pudo consultar el clima ($e)';
      debugPrint('[clima] $error');
      // Se permite reintentar más tarde.
      Future.delayed(const Duration(minutes: 2), () => _pedidos.remove(clave));
    }
  }

  /// Códigos WMO que usa Open-Meteo -> texto en español + icono.
  static (String, IconData) _descripcion(int c) {
    if (c == 0) return ('Despejado', Icons.wb_sunny_outlined);
    if (c <= 2) return ('Parcialmente nublado', Icons.wb_cloudy_outlined);
    if (c == 3) return ('Nublado', Icons.cloud_outlined);
    if (c == 45 || c == 48) return ('Niebla', Icons.foggy);
    if (c >= 51 && c <= 57) return ('Llovizna', Icons.grain);
    if (c >= 61 && c <= 65) return ('Lluvia', Icons.umbrella_outlined);
    if (c == 66 || c == 67) return ('Lluvia helada', Icons.ac_unit);
    if (c >= 71 && c <= 77) return ('Nieve', Icons.ac_unit);
    if (c >= 80 && c <= 82) return ('Chubascos', Icons.grain);
    if (c >= 95) return ('Tormenta', Icons.thunderstorm_outlined);
    return ('Variable', Icons.wb_cloudy_outlined);
  }
}
