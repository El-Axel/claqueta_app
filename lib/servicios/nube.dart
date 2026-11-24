import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos.dart';
import '../tienda.dart';
import 'captcha.dart';
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
// - El realizador entra con su CUENTA (correo y contraseña de Supabase
//   Auth). Google es aparte y opcional: solo para Gmail y Calendar.
//   (Quien empezó con Google puede seguir entrando con Google.)
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
  bool get iniciada => _iniciado;
  SupabaseClient get _db => Supabase.instance.client;

  /// Cliente de Supabase para el portal del cliente.
  SupabaseClient get db => _db;

  /// Conectada COMO REALIZADOR (con su cuenta). Un cliente entra como
  /// usuario anónimo y nunca sube los datos del realizador.
  bool get conectada {
    if (!_iniciado) return false;
    final u = _db.auth.currentUser;
    return u != null && !u.isAnonymous;
  }

  String get correo => conectada ? (_db.auth.currentUser!.email ?? '') : '';

  // Bandeja del realizador: lo que mandan los clientes desde su espacio.
  List<Map<String, dynamic>> solicitudesNuevas = [];
  List<Map<String, dynamic>> cambiosPedidos = [];
  Timer? _revision;

  /// Se llama una vez al abrir la app.
  Future<void> iniciar() async {
    if (!configurada || _iniciado) return;
    // Clave pública del proyecto (anon o "publishable"): segura en la app
    // porque la protege la seguridad por fila (RLS).
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    _iniciado = true;
    // Cada cambio en la tienda programa una subida, y cada novedad se
    // publica para el cliente.
    tienda.alGuardar = _programarSubida;
    tienda.alNovedad = (c, tipo, texto) => publicarNovedad(c, tipo, texto).catchError((_) {});
    _cambiar(conectada ? EstadoNube.alDia : EstadoNube.desconectado);
    if (conectada) _empezarRevision();
  }

  /// Revisa la bandeja ahora y luego cada minuto.
  void _empezarRevision() {
    _revision?.cancel();
    revisarBandeja().catchError((_) {});
    _revision = Timer.periodic(
        const Duration(minutes: 1), (_) => revisarBandeja().catchError((_) {}));
  }

  // ---------------- Portal del cliente (lado realizador) ----------------

  /// Publica un aviso en el espacio del cliente.
  Future<void> publicarNovedad(int clienteId, String tipo, String texto) async {
    if (!conectada) return;
    await _db.from('novedades').insert({
      'realizador_id': _db.auth.currentUser!.id,
      'cliente_id': clienteId,
      'tipo': tipo,
      'texto': texto,
    });
  }

  /// Trae las solicitudes nuevas y las respuestas de los clientes.
  /// - "Aceptar" se aplica sola: la cotización pasa a Aceptada.
  /// - "Pedir cambios" queda en la bandeja hasta que el realizador la vea.
  Future<void> revisarBandeja() async {
    if (!conectada) return;
    final uid = _db.auth.currentUser!.id;
    final resp = await _db
        .from('respuestas')
        .select()
        .eq('realizador_id', uid)
        .eq('procesada', false)
        .order('creada');
    final cambios = <Map<String, dynamic>>[];
    for (final r in resp) {
      if (r['accion'] == 'aceptar') {
        final n = r['cot_n'] as int;
        final cot = tienda.cotizacion(n);
        if (cot != null && cot.estado != estAceptada) {
          tienda.cambiarEstado(n, estAceptada);
        }
        await _db.from('respuestas').update({'procesada': true}).eq('id', r['id'] as int);
      } else {
        cambios.add(Map<String, dynamic>.from(r));
      }
    }
    final sol = await _db
        .from('solicitudes')
        .select()
        .eq('realizador_id', uid)
        .eq('estado', 'Nueva')
        .order('creada');
    cambiosPedidos = cambios;
    solicitudesNuevas = sol.map((e) => Map<String, dynamic>.from(e)).toList();
    notifyListeners();
  }

  /// Saca a quienes entraron como este cliente (con el código anterior).
  /// La seguridad por fila solo deja borrar accesos de MIS clientes.
  Future<void> revocarAccesos(int clienteId) async {
    if (!conectada) throw Exception('Conecta tu cuenta para cambiar el código en la nube');
    await _db.from('accesos_cliente').delete().eq('cliente_id', clienteId).eq('realizador_id', uid);
  }

  /// El realizador ya vio el pedido de cambios.
  Future<void> marcarCambioVisto(int id) async {
    await _db.from('respuestas').update({'procesada': true}).eq('id', id);
    cambiosPedidos.removeWhere((r) => r['id'] == id);
    notifyListeners();
  }

  /// Cambia el estado de una solicitud (En cotización · Descartada).
  Future<void> marcarSolicitud(int id, String estado) async {
    await _db.from('solicitudes').update({'estado': estado}).eq('id', id);
    solicitudesNuevas.removeWhere((s) => s['id'] == id);
    notifyListeners();
  }

  void _cambiar(EstadoNube e, [String? err]) {
    estado = e;
    error = err;
    notifyListeners();
  }

  // ---------------- Cuenta del realizador ----------------
  // La cuenta vive en Supabase Auth: el correo y la contraseña se guardan
  // en el servidor de Supabase (la contraseña cifrada con bcrypt, nunca en
  // texto plano). La app NO guarda la contraseña: solo la sesión (un token
  // que Supabase renueva solo), por eso no hay que volver a escribirla.

  /// Crea una cuenta nueva con correo y contraseña.
  Future<void> crearCuenta(String correo, String clave, {String nombre = ''}) async {
    await _antesDeEntrar();
    try {
      final r = await _db.auth.signUp(
        email: correo.trim(),
        password: clave,
        captchaToken: await tokenCaptcha(),
        data: nombre.trim().isEmpty ? null : {'nombre': nombre.trim()},
      );
      if (r.session == null) {
        // El proyecto pide confirmar el correo antes de entrar.
        throw Exception('Te enviamos un correo para confirmar la cuenta. '
            'Ábrelo y luego entra con "Ya tengo cuenta".');
      }
      _alEntrar();
    } on AuthException catch (e) {
      throw Exception(mensajeAuth(e));
    }
  }

  /// Entra con una cuenta que ya existe.
  Future<void> entrarConCorreo(String correo, String clave) async {
    await _antesDeEntrar();
    try {
      await _db.auth.signInWithPassword(
          email: correo.trim(), password: clave, captchaToken: await tokenCaptcha());
      _alEntrar();
    } on AuthException catch (e) {
      throw Exception(mensajeAuth(e));
    }
  }

  /// Pone (o cambia) la contraseña de la cuenta abierta. Sirve para quien
  /// entró con Google y quiere poder entrar también con correo y contraseña.
  Future<void> cambiarClave(String clave) async {
    if (!conectada) throw Exception('Primero entra a tu cuenta');
    try {
      await _db.auth.updateUser(UserAttributes(password: clave));
    } on AuthException catch (e) {
      throw Exception(mensajeAuth(e));
    }
  }

  /// Nombre con el que se creó la cuenta (si lo hay).
  String get nombreCuenta =>
      conectada ? '${_db.auth.currentUser!.userMetadata?['nombre'] ?? ''}' : '';

  /// Id de la cuenta abierta ('' si no hay).
  String get uid => conectada ? _db.auth.currentUser!.id : '';

  Future<void> _antesDeEntrar() async {
    if (!configurada) throw Exception('La nube no está configurada en esta versión');
    await iniciar();
    // Si había un cliente (anónimo) abierto en este teléfono, se cierra.
    final u = _db.auth.currentUser;
    if (u != null && u.isAnonymous) await _db.auth.signOut();
  }

  void _alEntrar() {
    _cambiar(EstadoNube.alDia);
    _empezarRevision();
  }

  /// Entra a Supabase con Google (opción para quien ya usaba Google).
  Future<void> conectar() async {
    await _antesDeEntrar();
    // Supabase necesita el token fresco que da el selector de Google. Solo
    // pasa la primera vez: luego Supabase guarda su propia sesión.
    if (servicioGoogle.cuenta == null) await servicioGoogle.entrar();
    final idToken = servicioGoogle.cuenta?.authentication.idToken;
    if (idToken == null) throw Exception('Google no entregó el token de inicio de sesión');
    try {
      await _db.auth.signInWithIdToken(
          provider: OAuthProvider.google, idToken: idToken, captchaToken: await tokenCaptcha());
      _alEntrar();
    } on AuthException catch (e) {
      _cambiar(EstadoNube.error, e.message);
      throw Exception('Supabase no aceptó el inicio de sesión: ${e.message}');
    }
  }

  Future<void> desconectar() async {
    _espera?.cancel();
    _revision?.cancel();
    solicitudesNuevas = [];
    cambiosPedidos = [];
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
          'codigo': (c['codigo'] ?? '') == '' ? null : c['codigo'],
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

/// Traduce los errores de Supabase Auth a mensajes claros en español.
String mensajeAuth(AuthException e) {
  final c = e.code ?? '';
  final m = e.message.toLowerCase();
  if (c == 'invalid_credentials' || m.contains('invalid login')) {
    return 'Correo o contraseña incorrectos';
  }
  if (c == 'email_not_confirmed' || m.contains('not confirmed')) {
    return 'Falta confirmar el correo: revisa tu bandeja de entrada';
  }
  if (c == 'user_already_exists' || m.contains('already registered')) {
    return 'Ya existe una cuenta con ese correo. Entra con "Ya tengo cuenta"';
  }
  if (c == 'weak_password' || m.contains('password should be')) {
    return 'La contraseña es muy débil: usa al menos 6 caracteres';
  }
  if (c == 'email_address_invalid' || m.contains('invalid format')) {
    return 'Ese correo no es válido';
  }
  if (c == 'over_email_send_rate_limit' || c == 'over_request_rate_limit') {
    return 'Demasiados intentos seguidos. Espera unos minutos';
  }
  if (c == 'signup_disabled') return 'Por ahora no se pueden crear cuentas nuevas';
  if (c == 'captcha_failed' || m.contains('captcha')) {
    return 'No pudimos verificar que eres una persona. Intenta de nuevo';
  }
  return e.message;
}
