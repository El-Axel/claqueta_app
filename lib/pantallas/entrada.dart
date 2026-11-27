import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tema.dart';
import '../selectores.dart';
import '../servicios/google_api.dart';
import '../servicios/nube.dart';
import '../servicios/portal_cliente.dart';
import 'cliente/piezas_cliente.dart';
import 'cliente/principal_cliente.dart';
import 'cuenta.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'principal.dart';
import '../estilo.dart';

// ---------------------------------------------------------------
// ENTRADA: una sola pantalla de acceso, con selector de rol.
// - Realizador: correo y contraseña a la vista, "Continuar con Google"
//   y enlace para crear cuenta.
// - Cliente: código de invitación.
// - En la web el realizador ve dónde descargar la app de Android.
// - Sin nube configurada: MODO DEMOSTRACIÓN.
// ---------------------------------------------------------------
class PantallaEntrada extends StatefulWidget {
  const PantallaEntrada({super.key});

  @override
  State<PantallaEntrada> createState() => _PantallaEntradaState();
}

class _PantallaEntradaState extends State<PantallaEntrada> {
  // En la web la app es el espacio del cliente: abre en "Cliente".
  late bool _esCliente = kIsWeb;
  bool _cargando = false;
  bool _verClave = false;
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _irAPrincipal() {
    tienda.iniciarSesion();
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const PantallaPrincipal()), (r) => false);
  }

  /// Ejecuta una acción de acceso mostrando "cargando" y los errores.
  Future<void> _intentar(Future<void> Function() accion) async {
    if (_cargando) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ---------- Realizador ----------
  Future<void> _entrarConCorreo() => _intentar(() async {
        final correo = _correo.text.trim();
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
          throw Exception('Escribe un correo válido');
        }
        if (_clave.text.isEmpty) throw Exception('Escribe tu contraseña');
        await servicioNube.entrarConCorreo(correo, _clave.text);
        if (!mounted) return;
        await sincronizarCuenta(context);
        if (mounted) _irAPrincipal();
      });

  Future<void> _entrarConGoogle() => _intentar(() async {
        if (!servicioGoogle.real) {
          ir(context, const PantallaGoogle());
          return;
        }
        await servicioGoogle.entrar();
        if (!mounted) return;
        await conectarNube(context);
        if (mounted) _irAPrincipal();
      });

  void _olvideClave() => hojaInferior<void>(
        context,
        (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Olvidaste tu contraseña?', style: estiloDisplay(tamano: 16)),
            const SizedBox(height: 8),
            Text(
              'Si tu cuenta es de Google, entra con "Continuar con Google" y crea una '
              'contraseña nueva en Ajustes → Nube → Contraseña.\n\n'
              'Si la creaste con correo, pide al administrador de Claqueta que la '
              'restablezca. Pronto llegará un enlace de recuperación a tu correo.',
              style: estiloSuave(tamano: 14),
            ),
            const SizedBox(height: 16),
            BotonClaqueta('Entendido', () => Navigator.pop(ctx)),
          ],
        ),
      );

  // ---------- Cliente ----------
  Future<void> _entrarComoCliente() => _intentar(() async {
        final codigo = _codigo.text.trim();
        if (codigo.isEmpty) throw Exception('Escribe tu código de invitación');
        await portal.entrarConCodigo(codigo);
        if (!mounted) return;
        pestanaCliente.value = 0;
        Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (_) => const PrincipalCliente()), (r) => false);
      });

  @override
  Widget build(BuildContext context) {
    final conNube = servicioNube.configurada;
    return Lienzo(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // En pantallas anchas (web) el formulario no se estira.
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                const _Marca(),
                const SizedBox(height: 48),
                _SelectorRol(
                  esCliente: _esCliente,
                  alCambiar: _cargando ? null : (v) => setState(() => _esCliente = v),
                ),
                const SizedBox(height: 32),
                if (!conNube)
                  ..._demostracion()
                else if (_esCliente)
                  ..._formCliente()
                else if (kIsWeb)
                  ..._realizadorWeb()
                else
                  ..._formRealizador(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formRealizador() => [
        Text('Bienvenido de nuevo', style: estiloDisplay(tamano: 28)),
        const SizedBox(height: 8),
        Text('Entra para cotizar, agendar y cobrar tus producciones.',
            style: estiloSuave(tamano: 15)),
        const SizedBox(height: 28),
        TextField(
          controller: _correo,
          enabled: !_cargando,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: decoracionCampo('Correo', icono: const Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clave,
          enabled: !_cargando,
          obscureText: !_verClave,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _entrarConCorreo(),
          decoration: decoracionCampo('Contraseña', icono: const Icon(Icons.lock_outline))
              .copyWith(
            suffixIcon: IconButton(
              tooltip: _verClave ? 'Ocultar contraseña' : 'Ver contraseña',
              icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _verClave = !_verClave),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _cargando ? null : _olvideClave,
            child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Paleta.arena)),
          ),
        ),
        const SizedBox(height: 4),
        BotonClaqueta(_cargando ? 'Un momento…' : 'Entrar', _cargando ? null : _entrarConCorreo),
        if (servicioGoogle.real) ...[
          const SizedBox(height: 22),
          const _Separador(),
          const SizedBox(height: 22),
          _BotonGoogle(alTocar: _cargando ? null : _entrarConGoogle),
        ],
        const SizedBox(height: 28),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('¿No tienes cuenta?', style: estiloSuave(tamano: 14)),
              TextButton(
                onPressed:
                    _cargando ? null : () => ir(context, const PantallaCuenta(crear: true)),
                child: const Text('Crear cuenta',
                    style: TextStyle(color: Paleta.arena, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ];

  List<Widget> _formCliente() => [
        Text('Tu espacio de cliente', style: estiloDisplay(tamano: 28)),
        const SizedBox(height: 8),
        Text('Escribe el código de invitación que te envió tu realizador.',
            style: estiloSuave(tamano: 15)),
        const SizedBox(height: 28),
        TextField(
          controller: _codigo,
          enabled: !_cargando,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 10, // "CLQ-" + 6 caracteres
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3),
          inputFormatters: [
            // Solo letras, números y guion, siempre en mayúsculas.
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            TextInputFormatter.withFunction(
                (viejo, nuevo) => nuevo.copyWith(text: nuevo.text.toUpperCase())),
          ],
          decoration: decoracionCampo('Código de invitación', ayuda: 'CLQ-XXXXXX')
              .copyWith(counterText: ''),
          onSubmitted: (_) => _entrarComoCliente(),
        ),
        const SizedBox(height: 18),
        BotonClaqueta(
            _cargando ? 'Entrando…' : 'Entrar', _cargando ? null : _entrarComoCliente),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 18, color: Paleta.tinta.withAlpha(150)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Solo verás tus cotizaciones, tus rodajes y los avisos de tu realizador. '
                'No necesitas crear una cuenta.',
                style: estiloSuave(tamano: 13),
              ),
            ),
          ],
        ),
      ];

  List<Widget> _realizadorWeb() => [
        Text('Claqueta para realizadores', style: estiloDisplay(tamano: 28)),
        const SizedBox(height: 8),
        Text(
          'Cotizar, agendar, cobrar y enviar por Gmail y Calendar se hace en la app de '
          'Android. Descárgala y entra con tu cuenta: tus datos te esperan en la nube.',
          style: estiloSuave(tamano: 15),
        ),
        const SizedBox(height: 28),
        BotonClaqueta('Descargar la app (Android)', () async {
          var ok = false;
          try {
            ok = await launchUrl(Uri.parse(enlaceApk), mode: LaunchMode.externalApplication);
          } catch (_) {}
          if (!ok && mounted) mostrarAviso(context, 'No se pudo abrir el enlace de descarga');
        }, icono: Icons.download_outlined),
        const SizedBox(height: 14),
        Text('En iPhone y en el navegador, Claqueta funciona como espacio del cliente.',
            style: estiloSuave(tamano: 13)),
      ];

  List<Widget> _demostracion() => [
        Text('Modo demostración', style: estiloDisplay(tamano: 28)),
        const SizedBox(height: 8),
        Text('Esta versión no tiene la nube configurada: entra con datos de ejemplo.',
            style: estiloSuave(tamano: 15)),
        const SizedBox(height: 28),
        BotonClaqueta('Entrar (demostración)', () => ir(context, const PantallaGoogle()),
            icono: Icons.login),
      ];
}

/// Logo pequeño + nombre: la marca arriba, sin ocupar media pantalla.
class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // El mismo ícono del celular (isotipo blanco sobre teal).
        Image.asset('assets/icono/icono_redondeado.png', width: 44, height: 44),
        const SizedBox(width: 12),
        Text('Claqueta', style: estiloDisplay(tamano: 20)),
      ],
    );
  }
}

/// Selector "Realizador | Cliente" en forma de píldora.
class _SelectorRol extends StatelessWidget {
  final bool esCliente;
  final ValueChanged<bool>? alCambiar;
  const _SelectorRol({required this.esCliente, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    Widget opcion(String texto, IconData icono, bool activa, bool valor) => Expanded(
          child: Semantics(
            button: true,
            selected: activa,
            child: GestureDetector(
              onTap: alCambiar == null ? null : () => alCambiar!(valor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activa ? Paleta.arena : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 18, color: activa ? Paleta.suelo : Paleta.tinta.withAlpha(170)),
                    const SizedBox(width: 8),
                    Text(texto,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: activa ? Paleta.suelo : Paleta.tinta.withAlpha(170),
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Row(
        children: [
          opcion('Realizador', Icons.videocam_outlined, !esCliente, false),
          opcion('Cliente', Icons.key_outlined, esCliente, true),
        ],
      ),
    );
  }
}

/// "──── o ────"
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    final linea = Expanded(child: Divider(color: Colors.white.withAlpha(40), height: 1));
    return Row(
      children: [
        linea,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('o', style: estiloSuave(tamano: 14)),
        ),
        linea,
      ],
    );
  }
}

/// Botón "Continuar con Google" con la "G" de colores (sin imagen externa).
class _BotonGoogle extends StatelessWidget {
  final VoidCallback? alTocar;
  const _BotonGoogle({required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: alTocar,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withAlpha(50)),
          backgroundColor: Colors.white.withAlpha(10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Text('G',
                  style: TextStyle(
                      color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            const Text('Continuar con Google',
                style: TextStyle(color: Paleta.tinta, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Dónde se descarga la última versión de la app de Android (APK).
const String enlaceApk = 'https://github.com/El-Axel/claqueta_app/releases/latest';

class PantallaGoogle extends StatefulWidget {
  const PantallaGoogle({super.key});

  @override
  State<PantallaGoogle> createState() => _PantallaGoogleState();
}

class _PantallaGoogleState extends State<PantallaGoogle> {
  int paso = 0; // 0 = elegir cuenta, 1 = permisos

  void entrar() {
    // En modo demostración se muestran datos de ejemplo si no hay nada.
    if (tienda.estaVacia) tienda.cargarEjemplos();
    tienda.iniciarSesion();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
      (ruta) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra(paso == 0 ? 'Conectar con Google' : 'Permisos'),
      body: Pagina(
        paso == 0
            ? [
                const Encabezado('Elige una cuenta', subtitulo: 'para continuar a Claqueta'),
                espacio(20),
                // Cuenta ficticia: esta pantalla es solo una demostración.
                FilaItem(
                  titulo: 'Cuenta de demostración',
                  subtitulo: 'demo@claqueta.app',
                  alTocar: () => setState(() => paso = 1),
                ),
                FilaItem(
                  titulo: 'Usar otra cuenta',
                  subtitulo: 'Disponible con Google configurado',
                  alTocar: () => mostrarAviso(
                      context, 'Modo demostración: con Google configurado se abre el selector real'),
                ),
                espacio(16),
                Text('Claqueta nunca ve tu contraseña. El acceso lo gestiona Google.',
                    style: estiloSuave(tamano: 13)),
              ]
            : [
                const Encabezado('Claqueta quiere acceso', subtitulo: 'demo@claqueta.app'),
                espacio(20),
                const Panel(
                  child: Column(
                    children: [
                      _Permiso(Icons.mail_outline, 'Enviar correos',
                          'Solo enviar tus cotizaciones. No puede leer tu bandeja.'),
                      SizedBox(height: 16),
                      _Permiso(Icons.event_outlined, 'Crear eventos en Calendar',
                          'Solo los eventos de rodaje que tú agendas.'),
                      SizedBox(height: 16),
                      _Permiso(Icons.place_outlined, 'Mapas y clima',
                          'OpenStreetMap y Open-Meteo: no piden cuenta ni tu ubicación.'),
                    ],
                  ),
                ),
                espacio(22),
                BotonClaqueta('Permitir', entrar),
                espacio(10),
                BotonClaqueta('Cancelar', () => setState(() => paso = 0), tipo: 'secundario'),
              ],
      ),
    );
  }
}

class _Permiso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Permiso(this.icono, this.titulo, this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: Paleta.arena, size: 22), // acento único (antes teal)
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(texto, style: estiloSuave(tamano: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
