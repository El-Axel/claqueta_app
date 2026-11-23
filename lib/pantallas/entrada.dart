import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tema.dart';
import '../selectores.dart';
import '../servicios/google_api.dart';
import '../servicios/nube.dart';
import 'cliente/codigo_cliente.dart';
import 'cuenta.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'principal.dart';
import '../estilo.dart';

// Pantalla de entrada: logo, tagline y botones por rol.
// - Realizador (Android): crea su cuenta o entra con correo y contraseña.
//   Quien empezó con Google puede seguir entrando con Google.
// - Cliente: entra con el código de invitación.
// - Sin nube configurada: MODO DEMOSTRACIÓN.
class PantallaEntrada extends StatefulWidget {
  const PantallaEntrada({super.key});

  @override
  State<PantallaEntrada> createState() => _PantallaEntradaState();
}

class _PantallaEntradaState extends State<PantallaEntrada> {
  bool cargando = false;

  Future<void> continuar() async {
    if (!servicioGoogle.real) {
      ir(context, const PantallaGoogle());
      return;
    }
    setState(() => cargando = true);
    try {
      await servicioGoogle.entrar();
      if (!mounted) return;
      // Nube: entra con Google y recupera los datos si ya existían.
      await conectarNube(context);
      if (!mounted) return;
      tienda.iniciarSesion();
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const PantallaPrincipal()), (r) => false);
    } catch (e) {
      if (mounted) mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Tarjeta suave del Home en lugar del degradado teal -> arena:
              // el logo es el único bloque de acento (arena) de la pantalla.
              TarjetaSuave(
                relleno: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Paleta.arena,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text('C', style: estiloDisplay(tamano: 32, color: Paleta.suelo)),
                    ),
                    const SizedBox(height: 34),
                    Text('Claqueta', style: estiloDisplay(tamano: 34)),
                    const SizedBox(height: 8),
                    Text(
                      'Cotiza, agenda y cobra tus producciones audiovisuales.',
                      style: TextStyle(
                          color: Paleta.tinta.withAlpha(170), fontSize: 15, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PildoraOscura('Maps', icono: Icons.place_outlined, sobreHero: false),
                  PildoraOscura('Clima', icono: Icons.wb_sunny_outlined, sobreHero: false),
                  PildoraOscura('Calendar', icono: Icons.event_outlined, sobreHero: false),
                  PildoraOscura('Gmail', icono: Icons.mail_outline, sobreHero: false),
                ],
              ),
              const Spacer(),
              // Dos roles: el realizador entra con Google; el cliente, con
              // el código de invitación que le envió su realizador.
              // En la WEB la app es el espacio del cliente: el realizador
              // trabaja en la app de Android (Gmail/Calendar reales).
              if (kIsWeb) ...[
                BotonClaqueta('Soy cliente · tengo un código',
                    () => ir(context, const PantallaCodigoCliente()),
                    icono: Icons.key_outlined),
                const SizedBox(height: 10),
                BotonClaqueta('Soy realizador · descargar la app',
                    () => _realizadorEnWeb(context),
                    tipo: 'secundario', icono: Icons.android),
              ] else if (servicioNube.configurada) ...[
                // Realizador: primero su CUENTA (correo y contraseña);
                // Google se conecta después, en Ajustes.
                BotonClaqueta('Soy realizador · crear cuenta',
                    cargando ? null : () => ir(context, const PantallaCuenta(crear: true)),
                    icono: Icons.person_add_alt_1_outlined),
                const SizedBox(height: 10),
                BotonClaqueta('Ya tengo cuenta',
                    cargando ? null : () => ir(context, const PantallaCuenta(crear: false)),
                    tipo: 'secundario', icono: Icons.login),
                const SizedBox(height: 10),
                BotonClaqueta('Soy cliente · tengo un código',
                    cargando ? null : () => ir(context, const PantallaCodigoCliente()),
                    tipo: 'secundario', icono: Icons.key_outlined),
                if (servicioGoogle.real)
                  Center(
                    child: TextButton(
                      onPressed: cargando ? null : continuar,
                      child: Text(cargando ? 'Conectando…' : 'Empecé con Google · entrar con Google',
                          style: estiloSuave(tamano: 13)),
                    ),
                  ),
              ] else ...[
                BotonClaqueta('Entrar (demostración)', () => ir(context, const PantallaGoogle()),
                    icono: Icons.login),
              ],
              const SizedBox(height: 12),
              Center(
                child: Text(
                    kIsWeb
                        ? 'Espacio del cliente · el realizador usa la app de Android'
                        : servicioNube.configurada
                            ? 'Tus datos se guardan en el teléfono y en tu cuenta en la nube'
                            : 'Modo demostración: la nube no está configurada en esta versión',
                    textAlign: TextAlign.center,
                    style: estiloSuave()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dónde se descarga la última versión de la app de Android (APK).
const String enlaceApk = 'https://github.com/El-Axel/claqueta_app/releases/latest';

/// En la web, el realizador ve dónde descargar la app de Android.
Future<void> _realizadorEnWeb(BuildContext context) => hojaInferior<void>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Claqueta para realizadores', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 8),
          Text(
            'Cotizar, agendar, cobrar y enviar por Gmail y Calendar se hace en la app de '
            'Android. Descárgala, instálala y entra con tu cuenta de Google: tus datos se '
            'guardan en la nube.',
            style: estiloSuave(tamano: 14),
          ),
          const SizedBox(height: 16),
          BotonClaqueta('Descargar la app (Android)', () async {
            var ok = false;
            try {
              ok = await launchUrl(Uri.parse(enlaceApk), mode: LaunchMode.externalApplication);
            } catch (_) {}
            if (!ok && ctx.mounted) mostrarAviso(ctx, 'No se pudo abrir el enlace de descarga');
          }, icono: Icons.download_outlined),
          const SizedBox(height: 10),
          Text('En iPhone y en el navegador, Claqueta funciona como espacio del cliente.',
              style: estiloSuave(tamano: 12)),
        ],
      ),
    );

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
