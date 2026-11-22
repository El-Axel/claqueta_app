import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos.dart';
import 'nube.dart';

// ---------------------------------------------------------------
// PORTAL DEL CLIENTE: lo que ve y hace el cliente en su espacio.
//
// - Entra como usuario ANÓNIMO de Supabase (sin correo ni contraseña)
//   y canjea su código de invitación (función canjear_codigo en la
//   base de datos). Desde ahí, las reglas de seguridad por fila le
//   dejan leer SOLO sus cotizaciones, rodajes y novedades.
// - No modifica los datos del realizador: sus acciones (aceptar,
//   pedir cambios, solicitar) se guardan en tablas aparte que el
//   realizador lee desde su app.
// - El rol elegido ("cliente") se recuerda en el teléfono.
// ---------------------------------------------------------------

final PortalCliente portal = PortalCliente();

const String _claveRol = 'claqueta-rol';
const String _claveVisto = 'claqueta-novedades-vistas';

class PortalCliente extends ChangeNotifier {
  // Perfil
  String? realizadorId;
  int? clienteId;
  String nombreCliente = '';
  String negocio = '';

  // Datos (solo lectura)
  List<Cotizacion> cotizaciones = [];
  List<Trabajo> trabajos = [];
  List<Map<String, dynamic>> solicitudes = [];
  List<Map<String, dynamic>> respuestas = [];
  List<Map<String, dynamic>> novedades = [];

  bool cargando = false;
  String? error;
  DateTime? _vistoHasta;

  bool get activo => realizadorId != null && clienteId != null;

  /// Novedades que llegaron después de la última vez que se abrió la pestaña.
  int get noLeidas => novedades.where((n) {
        final f = DateTime.tryParse(n['creada'] as String? ?? '');
        return f != null && (_vistoHasta == null || f.isAfter(_vistoHasta!));
      }).length;

  /// ¿Este teléfono quedó en modo cliente la última vez?
  static Future<bool> rolGuardadoEsCliente() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_claveRol) == 'cliente';
  }

  /// Al abrir la app en modo cliente: recupera la sesión anónima y el acceso.
  Future<bool> restaurar() async {
    if (!servicioNube.configurada) return false;
    await servicioNube.iniciar();
    final u = servicioNube.db.auth.currentUser;
    if (u == null) return false;
    final acceso = await servicioNube.db
        .from('accesos_cliente')
        .select('realizador_id, cliente_id')
        .eq('auth_uid', u.id)
        .maybeSingle();
    if (acceso == null) return false;
    realizadorId = acceso['realizador_id'] as String;
    clienteId = acceso['cliente_id'] as int;
    final p = await SharedPreferences.getInstance();
    _vistoHasta = DateTime.tryParse(p.getString(_claveVisto) ?? '');
    await cargar();
    return true;
  }

  /// Entrar con el código de invitación.
  Future<void> entrarConCodigo(String codigo) async {
    if (!servicioNube.configurada) {
      throw Exception('Esta versión de la app no tiene la nube configurada');
    }
    await servicioNube.iniciar();
    final auth = servicioNube.db.auth;
    if (auth.currentUser == null || !auth.currentUser!.isAnonymous) {
      if (auth.currentUser != null) await auth.signOut();
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw Exception('No se pudo iniciar el modo cliente (¿acceso anónimo activado en Supabase?)');
      }
    }
    try {
      final r = await servicioNube.db.rpc('canjear_codigo', params: {'p_codigo': codigo.trim()});
      final m = Map<String, dynamic>.from(r as Map);
      realizadorId = m['realizador_id'] as String;
      clienteId = m['cliente_id'] as int;
      nombreCliente = (m['cliente'] ?? '') as String;
      negocio = (m['negocio'] ?? '') as String;
    } catch (e) {
      final txt = e.toString();
      throw Exception(txt.contains('no válido')
          ? 'Ese código no existe. Revísalo con tu realizador.'
          : 'No se pudo validar el código. Revisa tu conexión.');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveRol, 'cliente');
    await cargar();
  }

  /// Trae todo lo del cliente desde Supabase.
  Future<void> cargar() async {
    if (!activo) return;
    cargando = true;
    error = null;
    notifyListeners();
    final db = servicioNube.db;
    try {
      final ficha = await db
          .from('clientes')
          .select('nombre')
          .eq('user_id', realizadorId!)
          .eq('id', clienteId!)
          .maybeSingle();
      if (ficha != null) nombreCliente = ficha['nombre'] as String;
      final cfg = await db.from('config').select('datos').eq('user_id', realizadorId!).maybeSingle();
      if (cfg != null) {
        negocio = ((cfg['datos'] as Map)['negocio'] ?? negocio) as String;
      }
      final cots = await db
          .from('cotizaciones')
          .select('datos')
          .eq('user_id', realizadorId!)
          .eq('cliente_id', clienteId!)
          .order('n', ascending: false);
      // El cliente no ve los borradores: solo lo que el realizador le envió.
      cotizaciones = cots
          .map((f) => Cotizacion.fromJson(Map<String, dynamic>.from(f['datos'] as Map)))
          .where((c) => c.estado != estBorrador)
          .toList();
      final trs = await db
          .from('trabajos')
          .select('datos')
          .eq('user_id', realizadorId!)
          .eq('cliente_id', clienteId!)
          .order('fecha');
      trabajos = trs.map((f) => Trabajo.fromJson(Map<String, dynamic>.from(f['datos'] as Map))).toList();
      solicitudes = (await db
              .from('solicitudes')
              .select()
              .eq('realizador_id', realizadorId!)
              .eq('cliente_id', clienteId!)
              .order('creada', ascending: false))
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      respuestas = (await db
              .from('respuestas')
              .select()
              .eq('realizador_id', realizadorId!)
              .eq('cliente_id', clienteId!)
              .order('creada', ascending: false))
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      novedades = (await db
              .from('novedades')
              .select()
              .eq('realizador_id', realizadorId!)
              .eq('cliente_id', clienteId!)
              .order('creada', ascending: false)
              .limit(50))
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      error = 'No se pudo actualizar. Revisa tu conexión.';
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Respuesta pendiente (aún no la procesa el realizador) para una cotización.
  Map<String, dynamic>? respuestaPendiente(int n) {
    for (final r in respuestas) {
      if (r['cot_n'] == n && r['procesada'] != true) return r;
    }
    return null;
  }

  /// Aceptar la cotización o pedir cambios (con mensaje).
  Future<void> responder(int n, String accion, {String mensaje = ''}) async {
    await servicioNube.db.from('respuestas').insert({
      'realizador_id': realizadorId,
      'cliente_id': clienteId,
      'cot_n': n,
      'accion': accion,
      'mensaje': mensaje.trim().isEmpty ? null : mensaje.trim(),
    });
    await cargar();
  }

  /// Pedir una cotización nueva.
  Future<void> solicitar({
    required String tipo,
    String descripcion = '',
    DateTime? fecha,
    String lugar = '',
  }) async {
    await servicioNube.db.from('solicitudes').insert({
      'realizador_id': realizadorId,
      'cliente_id': clienteId,
      'tipo': tipo.trim(),
      'descripcion': descripcion.trim().isEmpty ? null : descripcion.trim(),
      'fecha_tentativa': fecha == null
          ? null
          : '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
      'lugar': lugar.trim().isEmpty ? null : lugar.trim(),
    });
    await cargar();
  }

  /// Al abrir la pestaña Novedades: todo queda como leído.
  Future<void> marcarNovedadesVistas() async {
    _vistoHasta = DateTime.now().toUtc();
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveVisto, _vistoHasta!.toIso8601String());
    notifyListeners();
  }

  /// Salir del modo cliente (vuelve a la pantalla de entrada).
  Future<void> salir() async {
    try {
      await servicioNube.db.auth.signOut();
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.remove(_claveRol);
    realizadorId = null;
    clienteId = null;
    cotizaciones = [];
    trabajos = [];
    solicitudes = [];
    respuestas = [];
    novedades = [];
    notifyListeners();
  }
}
