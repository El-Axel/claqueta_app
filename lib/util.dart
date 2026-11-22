import 'package:flutter/material.dart';
import 'modelos.dart';
import 'servicios/clima_api.dart';
import 'tienda.dart';

// ---------------------------------------------------------------
// Funciones de ayuda: formato de pesos, fechas, horas, clima y lugares.
// Son funciones "puras": reciben datos y devuelven un resultado, sin
// depender de ninguna pantalla. Por eso son fáciles de probar.
// ---------------------------------------------------------------

const List<String> _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const List<String> _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];
const List<String> mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

/// 1270000 -> $1.270.000
String formatearPesos(int valor) {
  final negativo = valor < 0;
  final texto = valor.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '${negativo ? '-' : ''}\$${buffer.toString()}';
}

/// Versión corta para gráficas: 1500000 -> 1.5M, 450000 -> 450k
String pesosCortos(int valor) {
  if (valor >= 1000000) {
    final m = valor / 1000000;
    return '\$${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)}M';
  }
  if (valor >= 1000) return '\$${(valor / 1000).round()}k';
  return '\$$valor';
}

String folio(int n) => 'COT-${n.toString().padLeft(4, '0')}';

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String nombreDia(DateTime d) => _dias[d.weekday - 1];

String fechaCorta(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';

String fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} de ${mesesLargos[d.month - 1]} de ${d.year}';

String mesAbreviado(DateTime d) => _meses[d.month - 1];

/// "14:00" -> "2:00 pm"
String hora12(String hora) {
  final partes = hora.split(':');
  int h = int.parse(partes[0]);
  final m = partes[1];
  final sufijo = h >= 12 ? 'pm' : 'am';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $sufijo';
}

int minutos(String hora) {
  final partes = hora.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes[1]);
}

String horaDe(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay timeDe(String hora) {
  final partes = hora.split(':');
  return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
}

String inicialDe(String texto) =>
    texto.trim().isEmpty ? '?' : texto.trim()[0].toUpperCase();

/// Días que han pasado desde una fecha hasta hoy.
int diasDesde(DateTime fecha) =>
    soloFecha(DateTime.now()).difference(soloFecha(fecha)).inDays;

/// Solo dígitos de un teléfono; agrega el 57 de Colombia si hace falta.
String telefonoParaWhatsApp(String telefono) {
  var d = telefono.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 10) d = '57$d';
  return d;
}

// ---------------------------------------------------------------
// CLIMA. Real con Open-Meteo (servicios/clima_api.dart) para los
// próximos 16 días. Si no hay internet o la fecha es más lejana, se
// usa un clima ESTIMADO que sale de la fecha (siempre igual para el
// mismo día) y la pantalla lo marca como "Estimado".
// ---------------------------------------------------------------
class Clima {
  final String descripcion;
  final int temperatura;
  final int lluvia; // probabilidad en %
  final int viento; // km/h
  final IconData icono;
  final bool real; // true = pronóstico de Open-Meteo

  const Clima(this.descripcion, this.temperatura, this.lluvia, this.viento, this.icono,
      {this.real = false});

  bool get riesgoLluvia => lluvia >= 60;
}

const List<Clima> _opcionesClima = [
  Clima('Soleado', 26, 5, 6, Icons.wb_sunny_outlined),
  Clima('Parcialmente nublado', 24, 20, 8, Icons.wb_cloudy_outlined),
  Clima('Nublado', 22, 35, 10, Icons.cloud_outlined),
  Clima('Lluvia ligera', 20, 70, 12, Icons.grain),
  Clima('Soleado', 27, 5, 7, Icons.wb_sunny_outlined),
  Clima('Tormentas aisladas', 19, 80, 14, Icons.thunderstorm_outlined),
  Clima('Parcialmente nublado', 23, 25, 9, Icons.wb_cloudy_outlined),
];

/// Clima para una fecha (y lugar, si se conoce). Real si Open-Meteo ya
/// respondió; si no, estimado.
Clima climaDe(DateTime fecha, {double? lat, double? lon}) {
  // Sin coordenadas del lugar, se usa la zona base del usuario (Ajustes).
  final real = servicioClima.pronostico(
      fecha, lat ?? tienda.config.lat, lon ?? tienda.config.lon);
  if (real != null) return real;
  final i = (fecha.day * 3 + fecha.month) % _opcionesClima.length;
  return _opcionesClima[i];
}

/// Clima de un rodaje, usando sus coordenadas si las tiene.
Clima climaTrabajo(Trabajo t) {
  final c = coordenadasTrabajo(t);
  return climaDe(t.fecha, lat: c?.$1, lon: c?.$2);
}

/// Coordenadas del rodaje: las guardadas o, para los datos de ejemplo,
/// las del lugar conocido con ese nombre.
(double, double)? coordenadasTrabajo(Trabajo t) {
  if (t.lat != null && t.lon != null) return (t.lat!, t.lon!);
  for (final l in lugaresEjemplo) {
    if (l.nombre == t.lugar && l.lat != null) return (l.lat!, l.lon!);
  }
  return null;
}

// ---------------------------------------------------------------
// LUGARES. La búsqueda real usa OpenStreetMap (servicios/lugares_api.dart).
// Estos son los lugares de los datos de ejemplo, con coordenadas
// aproximadas, y sirven de sugerencias sin conexión.
// ---------------------------------------------------------------
class Lugar {
  final String nombre;
  final String zona;
  final double? lat;
  final double? lon;
  const Lugar(this.nombre, this.zona, {this.lat, this.lon});
}

const List<Lugar> lugaresEjemplo = [
  Lugar('Parque Lleras', 'El Poblado, Medellín', lat: 6.2087, lon: -75.5671),
  Lugar('Parque Arví', 'Santa Elena, Medellín', lat: 6.2814, lon: -75.4981),
  Lugar('Plaza Botero', 'La Candelaria, Medellín', lat: 6.2518, lon: -75.5687),
  Lugar('Jardín Botánico', 'Chagualo, Medellín', lat: 6.2706, lon: -75.5640),
  Lugar('Comuna 13', 'San Javier, Medellín', lat: 6.2546, lon: -75.6110),
  Lugar('Parque de Envigado', 'Envigado, Antioquia', lat: 6.1711, lon: -75.5869),
  Lugar('Pueblito Paisa', 'Cerro Nutibara, Medellín', lat: 6.2370, lon: -75.5800),
];
