import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tienda.dart';
import 'google_api.dart';

// ---------------------------------------------------------------
// NUBE con Supabase (PostgreSQL): los datos sobreviven a desinstalar
// la app o cambiar de teléfono.
//
// Cómo funciona:
// - La app sigue guardando TODO en el teléfono (funciona sin internet).
// - Cada vez que algo cambia, 2 segundos después se sube una copia a
//   Supabase ("debounce": si haces 5 cambios seguidos, sube una vez).
// - Al iniciar sesión en un teléfono nuevo, la app ofrece traer los
//   datos de la nube.
// - Para entrar a Supabase se reutiliza el inicio de sesión de Google
//   (el "ID token" que Google entrega a la app).
// - Seguridad: cada fila lleva el user_id del dueño y la base de datos
//   (RLS) solo deja ver/cambiar las propias filas.
//
// La URL y la clave pública (anon) se pasan al compilar, igual que el
// ID de Google: --dart-define-from-file=dart_defines.json
// ---------------------------------------------------------------

const String _url = String.fromEnvironment('SUPABASE_URL');
const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final ServicioNube servicioNube = ServicioNube();

enum EstadoNube { sinConfigurar, desconectado, sincronizando, alDia, error }

/// Resumen de lo que hay guardado en la nube (para preguntar al usuario).
class ResumenNube {
  final int clientes;
  final int cotizaciones;
  final int trabajos;
  final DateTime? actualizado;
  const ResumenNube(this.clientes, this.cotizaciones, this.trabajos, this.actualizado);
  bool get vacia => clientes == 0 && cotizaciones == 0 && trabajos == 0;
}

class ServicioNube extends ChangeNotifier {
  EstadoNube estado = EstadoNube.sinConfigurar;
  String? error;
  DateTime? ultimaSubida;
  bool _iniciado = false;
  bool _aplicandoDescarga = false;
  Timer? _espera;

  bool get configurada => _url.isNotEmpty && _anonKey.isNotEmpty;
  SupabaseClient get _db => Supabase.instance.client;
  bool get conectada => _iniciado && _db.auth.currentUser != null;
  String get correo => conectada ? (_db.auth.currentUser!.email ?? '') : '';

  /// Se llama una vez al abrir la app.
  Future<void> iniciar() async {
    if (!configurada || _iniciado) return;
    // Clave pública del proyecto (anon o "publishable"): segura en la app
    // porque la protege la seguridad por fila (RLS).
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    _iniciado = true;
    // Cada cambio en la tienda programa una subida.
    tienda.alGuardar = _programarSubida;
    _cambiar(conectada ? EstadoNube.alDia : EstadoNube.desconectado);
  }

  void _cambiar(EstadoNube e, [String? err]) {
    estado = e;
    error = err;
    notifyListeners();
  }

  /// Entra a Supabase con la cuenta de Google ya conectada en la app.
  Future<void> conectar() async {
    if (!configurada) throw Exception('Supabase no está configurado en esta versión');
    await iniciar();
    if (!servicioGoogle.conectado) await servicioGoogle.entrar();
    final idToken = servicioGoogle.cuenta?.authentication.idToken;
    if (idToken == null) throw Exception('Google no entregó el token de inicio de sesión');
    try {
      await _db.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
      _cambiar(EstadoNube.alDia);
    } on AuthException catch (e) {
      _cambiar(EstadoNube.error, e.message);
      throw Exception('Supabase no aceptó el inicio de sesión: ${e.message}');
    }
  }

  Future<void> desconectar() async {
    _espera?.cancel();
    if (_iniciado) await _db.auth.signOut();
    _cambiar(configurada ? EstadoNube.desconectado : EstadoNube.sinConfigurar);
  }

  // ---------------- Subir ----------------

  void _programarSubida() {
    if (!conectada || _aplicandoDescarga) return;
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 2), () => subir().catchError((_) {}));
  }

  /// Sube todos los datos del teléfono a Supabase.
  /// Orden: primero clientes (las cotizaciones y trabajos dependen de
  /// ellos), luego lo demás; al final se borra en la nube lo que ya no
  /// existe en el teléfono.
  Future<void> subir() async {
    if (!conectada) return;
    _cambiar(EstadoNube.sincronizando);
    try {
      final uid = _db.auth.currentUser!.id;
      final filas = filasParaSubir(tienda.instantanea(), uid);
      for (final tabla in ['clientes', 'servicios', 'paquetes', 'cotizaciones', 'trabajos']) {
        final lista = filas[tabla]!;
        if (lista.isNotEmpty) await _db.from(tabla).upsert(lista);
      }
      await _db.from('config').upsert(filas['config']!.first);
      // Borrar lo que se eliminó en el teléfono (orden inverso).
      for (final t in [
        ('trabajos', 'id'),
        ('cotizaciones', 'n'),
        ('paquetes', 'id'),
        ('servicios', 'id'),
        ('clientes', 'id'),
      ]) {
        final ids = filas[t.$1]!.map((f) => f[t.$2] as int).toList();
        final q = _db.from(t.$1).delete().eq('user_id', uid);
        await (ids.isEmpty ? q : q.not(t.$2, 'in', '(${ids.join(',')})'));
      }
      ultimaSubida = DateTime.now();
      _cambiar(EstadoNube.alDia);
    } catch (e) {
      _cambiar(EstadoNube.error, e.toString());
      rethrow;
    }
  }

  // ---------------- Bajar ----------------

  Future<ResumenNube> resumen() async {
    final cl = await _db.from('clientes').select('id');
    final co = await _db.from('cotizaciones').select('n');
    final tr = await _db.from('trabajos').select('id');
    final cfg = await _db.from('config').select('actualizado').maybeSingle();
    return ResumenNube(
      cl.length,
      co.length,
      tr.length,
      cfg == null ? null : DateTime.tryParse(cfg['actualizado'] as String)?.toLocal(),
    );
  }

  /// Reemplaza los datos del teléfono por los de la nube.
  Future<void> bajar() async {
    if (!conectada) return;
    _cambiar(EstadoNube.sincronizando);
    try {
      List<Map<String, dynamic>> datos(List<Map<String, dynamic>> filas) =>
          filas.map((f) => Map<String, dynamic>.from(f['datos'] as Map)).toList();
      final cfg = await _db.from('config').select('datos').maybeSingle();
      final j = <String, dynamic>{
        'config': cfg?['datos'],
        'clientes': datos(await _db.from('clientes').select('datos').order('id')),
        'servicios': datos(await _db.from('servicios').select('datos').order('id')),
        'paquetes': datos(await _db.from('paquetes').select('datos').order('id')),
        'cotizaciones': datos(await _db.from('cotizaciones').select('datos').order('n')),
        'trabajos': datos(await _db.from('trabajos').select('datos').order('id')),
      };
      _aplicandoDescarga = true;
      tienda.reemplazarDesde(j);
      _aplicandoDescarga = false;
      _cambiar(EstadoNube.alDia);
    } catch (e) {
      _aplicandoDescarga = false;
      _cambiar(EstadoNube.error, e.toString());
      rethrow;
    }
  }
}

/// Convierte la copia de la tienda en filas para cada tabla de Supabase.
/// Es una función aparte (sin red) para poder probarla.
Map<String, List<Map<String, dynamic>>> filasParaSubir(Map<String, dynamic> j, String uid) {
  List<Map<String, dynamic>> lista(String k) =>
      ((j[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final ahora = DateTime.now().toUtc().toIso8601String();
  return {
    'clientes': [
      for (final c in lista('clientes'))
        {
          'id': c['id'],
          'nombre': c['nombre'],
          'correo': c['correo'],
          'telefono': c['telefono'],
          'datos': c,
          'actualizado': ahora, 'user_id': uid,
        }
    ],
    'servicios': [
      for (final s in lista('servicios'))
        {'id': s['id'], 'nombre': s['nombre'], 'precio': s['precio'] ?? 0, 'datos': s, 'actualizado': ahora, 'user_id': uid}
    ],
    'paquetes': [
      for (final p in lista('paquetes'))
        {'id': p['id'], 'nombre': p['nombre'], 'datos': p, 'actualizado': ahora, 'user_id': uid}
    ],
    'cotizaciones': [
      for (final c in lista('cotizaciones'))
        {
          'n': c['n'],
          'cliente_id': c['clienteId'],
          'proyecto': c['proyecto'],
          'estado': c['estado'],
          'total': _totalDe(c),
          'datos': c,
          'actualizado': ahora, 'user_id': uid,
        }
    ],
    'trabajos': [
      for (final t in lista('trabajos'))
        {
          'id': t['id'],
          'cliente_id': t['clienteId'],
          'cot_n': t['cotN'],
          'titulo': t['titulo'],
          'fecha': t['fecha'],
          'lugar': t['lugar'],
          'valor': t['valor'] ?? 0,
          'datos': t,
          'actualizado': ahora, 'user_id': uid,
        }
    ],
    'config': [
      {'datos': j['config'], 'actualizado': ahora, 'user_id': uid}
    ],
  };
}

/// Total de una cotización a partir de su JSON (mismo cálculo que el modelo).
int _totalDe(Map<String, dynamic> c) {
  final items = (c['items'] ?? []) as List;
  final subtotal = items.fold<int>(
      0, (a, i) => a + ((i['precio'] ?? 0) as int) * ((i['cantidad'] ?? 1) as int));
  final desc = (subtotal * ((c['descuento'] ?? 0) as int) / 100).round();
  final base = subtotal - desc;
  final iva = (c['iva'] ?? false) == true ? (base * 0.19).round() : 0;
  return base + iva;
}
