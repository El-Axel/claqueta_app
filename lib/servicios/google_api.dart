import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos.dart';

// ---------------------------------------------------------------
// GOOGLE: inicio de sesión + Gmail (enviar) + Calendar (eventos).
//
// - Solo se piden DOS permisos (scopes):
//     gmail.send       -> enviar correos, NO leer la bandeja.
//     calendar.events  -> crear/editar/borrar eventos, NO ver otros
//                         calendarios ni configuraciones.
// - No hay Client Secret en la app (una app móvil no puede guardar
//   secretos). Se usa el ID de cliente "web" de Google Cloud, que es
//   público, y se pasa al compilar:
//     flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
// - Si no se pasa el ID, o si la app corre en web, funciona en
//   MODO DEMOSTRACIÓN: los pasos se ven igual pero no se conecta.
// ---------------------------------------------------------------

const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

const List<String> scopesGoogle = [
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/calendar.events',
];

final ServicioGoogle servicioGoogle = ServicioGoogle();

// Cuenta recordada en el teléfono: la sesión queda iniciada aunque se
// cierre y abra la app, hasta que el usuario toque "Cerrar sesión".
const String _claveCorreo = 'claqueta-google-correo';
const String _claveNombre = 'claqueta-google-nombre';

class ServicioGoogle extends ChangeNotifier {
  GoogleSignInAccount? cuenta;
  bool _iniciado = false;
  String _correoGuardado = '';
  String _nombreGuardado = '';

  /// true = conexión real con Google; false = modo demostración.
  bool get real => _webClientId.isNotEmpty && !kIsWeb;

  /// Conectado si Google entregó la cuenta en esta sesión O si quedó
  /// recordada de antes (Android a veces no la devuelve en silencio al
  /// abrir; los permisos de Gmail/Calendar se piden igual sin selector).
  bool get conectado => cuenta != null || _correoGuardado.isNotEmpty;
  String get correo => cuenta?.email ?? _correoGuardado;
  String get nombre => cuenta?.displayName ?? _nombreGuardado;

  Future<void> iniciar() async {
    if (!real || _iniciado) return;
    _iniciado = true;
    final p = await SharedPreferences.getInstance();
    _correoGuardado = p.getString(_claveCorreo) ?? '';
    _nombreGuardado = p.getString(_claveNombre) ?? '';
    notifyListeners();
    final g = GoogleSignIn.instance;
    await g.initialize(serverClientId: _webClientId);
    g.authenticationEvents.listen((e) {
      // Solo se actualiza con un inicio de sesión: si Android no entrega la
      // cuenta en silencio, la sesión recordada se mantiene.
      if (e is GoogleSignInAuthenticationEventSignIn) {
        cuenta = e.user;
        _recordar(e.user);
        notifyListeners();
      }
    }, onError: (_) {});
    // Recupera la sesión anterior sin mostrar nada, SOLO si ya se había
    // conectado Google antes. Sin sesión previa, Android abriría por su
    // cuenta la ventana "Use your account for Claqueta" en la entrada.
    if (_correoGuardado.isNotEmpty) {
      unawaited(g.attemptLightweightAuthentication()?.catchError((_) => null));
    }
  }

  Future<void> _recordar(GoogleSignInAccount u) async {
    _correoGuardado = u.email;
    _nombreGuardado = u.displayName ?? '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveCorreo, _correoGuardado);
    await p.setString(_claveNombre, _nombreGuardado);
  }

  /// Abre el selector de cuentas de Google y pide los dos permisos.
  /// Lanza una excepción con un mensaje en español si algo falla.
  Future<void> entrar() async {
    await iniciar();
    try {
      final u = await GoogleSignIn.instance.authenticate(scopeHint: scopesGoogle);
      await u.authorizationClient.authorizeScopes(scopesGoogle);
      cuenta = u;
      await _recordar(u);
      notifyListeners();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Inicio de sesión cancelado');
      }
      throw Exception('Google no aceptó la configuración: ${e.description ?? e.code.name}');
    }
  }

  /// Cerrar sesión: lo único que borra la cuenta recordada.
  Future<void> salir() async {
    if (real) await GoogleSignIn.instance.signOut();
    cuenta = null;
    _correoGuardado = '';
    _nombreGuardado = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_claveCorreo);
    await p.remove(_claveNombre);
    notifyListeners();
  }

  /// Token para Gmail/Calendar. Primero en silencio (permisos ya
  /// aceptados antes); si Google exige confirmar, muestra su ventana.
  Future<Map<String, String>> _cabeceras() async {
    if (!conectado) throw Exception('Primero inicia sesión con Google');
    final cliente = cuenta?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    GoogleSignInClientAuthorization? auth;
    try {
      auth = await cliente.authorizationForScopes(scopesGoogle);
    } catch (_) {}
    if (auth == null) {
      try {
        auth = await cliente.authorizeScopes(scopesGoogle);
      } on GoogleSignInException catch (e) {
        throw Exception(e.code == GoogleSignInExceptionCode.canceled
            ? 'Se canceló el permiso de Google'
            : 'Google pidió volver a iniciar sesión (Ajustes → Conectar)');
      }
    }
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  // ---------------- Gmail ----------------

  /// Envía un correo desde la cuenta del usuario, con un PDF adjunto.
  Future<void> enviarCorreo({
    required String para,
    required String asunto,
    required String cuerpo,
    String? html,
    Uint8List? pdf,
    String nombrePdf = 'cotizacion.pdf',
  }) async {
    final mime = construirMime(
        para: para,
        asunto: asunto,
        cuerpo: cuerpo,
        html: html,
        pdf: pdf,
        nombrePdf: nombrePdf);
    final r = await http
        .post(
          Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/messages/send'),
          headers: await _cabeceras(),
          body: jsonEncode({'raw': base64Url.encode(utf8.encode(mime))}),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 300) throw Exception(_errorDe('Gmail', r));
  }

  // ---------------- Calendar ----------------

  static const _cal = '/calendar/v3/calendars/primary/events';

  Map<String, dynamic> _evento(Trabajo t, {String? invitado}) {
    final partes = t.hora.split(':');
    final inicio = DateTime(t.fecha.year, t.fecha.month, t.fecha.day,
        int.parse(partes[0]), int.parse(partes[1]));
    final fin = inicio.add(const Duration(hours: 4)); // duración típica de rodaje
    String iso(DateTime d) => d.toIso8601String().substring(0, 19);
    return {
      'summary': 'Rodaje: ${t.titulo}',
      'location': t.zona.isEmpty ? t.lugar : '${t.lugar}, ${t.zona}',
      'description': 'Agendado desde Claqueta.',
      'start': {'dateTime': iso(inicio), 'timeZone': 'America/Bogota'},
      'end': {'dateTime': iso(fin), 'timeZone': 'America/Bogota'},
      if (invitado != null && invitado.isNotEmpty)
        'attendees': [
          {'email': invitado}
        ],
    };
  }

  /// Crea el evento y devuelve (id, enlace para abrirlo).
  Future<(String, String)> crearEvento(Trabajo t, {String? invitado}) async {
    final r = await http
        .post(
          Uri.https('www.googleapis.com', _cal,
              {'sendUpdates': invitado == null ? 'none' : 'all'}),
          headers: await _cabeceras(),
          body: jsonEncode(_evento(t, invitado: invitado)),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception(_errorDe('Calendar', r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['id'] as String, (j['htmlLink'] ?? '') as String);
  }

  Future<void> actualizarEvento(String id, Trabajo t) async {
    final r = await http
        .patch(
          Uri.https('www.googleapis.com', '$_cal/$id', {'sendUpdates': 'all'}),
          headers: await _cabeceras(),
          body: jsonEncode(_evento(t)..remove('attendees')),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception(_errorDe('Calendar', r));
  }

  Future<void> eliminarEvento(String id) async {
    final r = await http
        .delete(Uri.https('www.googleapis.com', '$_cal/$id', {'sendUpdates': 'all'}),
            headers: await _cabeceras())
        .timeout(const Duration(seconds: 20));
    // 404/410: ya no existía; no es un error para el usuario.
    if (r.statusCode >= 300 && r.statusCode != 404 && r.statusCode != 410) {
      throw Exception(_errorDe('Calendar', r));
    }
  }

  String _errorDe(String api, http.Response r) {
    try {
      final m = (jsonDecode(r.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      return '$api respondió ${r.statusCode}: ${m['message']}';
    } catch (_) {
      return '$api respondió ${r.statusCode}';
    }
  }
}

/// Correo en formato MIME, como lo pide Gmail. Estructura:
///   multipart/mixed
///     ├─ multipart/alternative   (el programa de correo elige una)
///     │    ├─ text/plain          (versión sin diseño)
///     │    └─ text/html           (versión con diseño, si hay)
///     └─ application/pdf         (adjunto, si hay)
/// Es una función aparte para poder probarla sin conexión.
String construirMime({
  required String para,
  required String asunto,
  required String cuerpo,
  String? html,
  Uint8List? pdf,
  String nombrePdf = 'cotizacion.pdf',
}) {
  String b64(String s) => base64.encode(utf8.encode(s));
  // base64 en líneas de 76 caracteres, como pide el estándar MIME.
  String lineas(String s) =>
      RegExp('.{1,76}').allMatches(s).map((m) => m.group(0)).join('\r\n');
  final asuntoCodificado = '=?UTF-8?B?${b64(asunto)}?=';
  const limite = 'claqueta-limite-mime';
  const limiteAlt = 'claqueta-limite-alt';

  String parteTexto(String tipo, String contenido) =>
      'Content-Type: $tipo; charset="UTF-8"\r\n'
      'Content-Transfer-Encoding: base64\r\n\r\n'
      '${lineas(b64(contenido))}\r\n';

  // Cuerpo: solo texto, o texto + HTML como alternativas.
  final cuerpoMime = html == null
      ? parteTexto('text/plain', cuerpo)
      : 'Content-Type: multipart/alternative; boundary="$limiteAlt"\r\n\r\n'
          '--$limiteAlt\r\n${parteTexto('text/plain', cuerpo)}'
          '--$limiteAlt\r\n${parteTexto('text/html', html)}'
          '--$limiteAlt--\r\n';

  final b = StringBuffer()
    ..write('To: $para\r\n')
    ..write('Subject: $asuntoCodificado\r\n')
    ..write('MIME-Version: 1.0\r\n');
  if (pdf == null) {
    b.write(cuerpoMime);
    return b.toString();
  }
  b
    ..write('Content-Type: multipart/mixed; boundary="$limite"\r\n\r\n')
    ..write('--$limite\r\n')
    ..write(cuerpoMime)
    ..write('--$limite\r\n')
    ..write('Content-Type: application/pdf; name="$nombrePdf"\r\n')
    ..write('Content-Disposition: attachment; filename="$nombrePdf"\r\n')
    ..write('Content-Transfer-Encoding: base64\r\n\r\n')
    ..write('${lineas(base64.encode(pdf))}\r\n')
    ..write('--$limite--');
  return b.toString();
}
