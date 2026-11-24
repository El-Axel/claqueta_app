import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';

// ---------------------------------------------------------------
// CAPTCHA con Cloudflare Turnstile (gratis y casi invisible).
//
// Para qué: que solo PERSONAS puedan crear cuentas, entrar o canjear
// códigos de cliente. Un bot (o una IA automatizada) no consigue el
// "token" que Turnstile entrega tras revisar el navegador.
//
// Cómo funciona:
// 1. La app pide a Turnstile un token (modo invisible: normalmente el
//    usuario no ve nada).
// 2. La app manda ese token a Supabase junto con el inicio de sesión.
// 3. Supabase lo verifica con Cloudflare usando la clave SECRETA (que
//    solo está en Supabase, nunca en la app). Si no es válido, rechaza.
//
// La clave del sitio (pública) se pasa al compilar:
// --dart-define-from-file=dart_defines.json  →  "TURNSTILE_SITE_KEY".
// Sin clave, la app funciona igual pero sin CAPTCHA (así no se rompe nada
// antes de activarlo en Supabase).
// ---------------------------------------------------------------

const String _siteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

/// Dominio registrado en el widget de Cloudflare. En Android/iOS el
/// widget necesita un dominio de la lista; en la web se usa el propio.
const String _dominio = 'https://claqueta-alexpino.netlify.app';

bool get captchaActivo => _siteKey.isNotEmpty;

/// Devuelve un token de Turnstile, o null si el CAPTCHA no está activado.
Future<String?> tokenCaptcha() async {
  if (!captchaActivo) return null;
  final turnstile = CloudflareTurnstile.invisible(
    siteKey: _siteKey,
    baseUrl: _dominio,
    options: TurnstileOptions(language: 'es'),
  );
  try {
    final token = await turnstile.getToken();
    if (token == null || token.isEmpty) throw Exception('sin token');
    return token;
  } catch (_) {
    throw Exception('No pudimos verificar que eres una persona. Revisa tu conexión e intenta de nuevo.');
  } finally {
    turnstile.dispose();
  }
}
