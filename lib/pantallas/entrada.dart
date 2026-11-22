import 'package:flutter/material.dart';
import '../tema.dart';
import '../selectores.dart';
import '../servicios/google_api.dart';
import '../servicios/nube.dart';
import 'cliente/codigo_cliente.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'principal.dart';
import '../estilo.dart';

// Pantalla de entrada: logo, tagline y botón de Google.
// - Con Google configurado: abre el selector real de cuentas y pide
//   solo los permisos gmail.send y calendar.events.
// - Sin configurar (o en web): MODO DEMOSTRACIÓN con los mismos pasos.
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
      // Nube: recupera los datos si ya existían (p. ej. tras reinstalar).
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
              BotonClaqueta(cargando ? 'Conectando…' : 'Soy realizador · Continuar con Google',
                  cargando ? null : continuar,
                  icono: Icons.login),
              if (servicioNube.configurada) ...[
                const SizedBox(height: 10),
                BotonClaqueta('Soy cliente · tengo un código',
                    cargando ? null : () => ir(context, const PantallaCodigoCliente()),
                    tipo: 'secundario', icono: Icons.key_outlined),
              ],
              const SizedBox(height: 12),
              Center(
                child: Text(
                    !servicioGoogle.real
                        ? 'Modo demostración: Google no está configurado en esta versión'
                        : servicioNube.configurada
                            ? 'Tus datos se guardan en el teléfono y en la nube'
                            : 'Tus datos se guardan en este dispositivo',
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

class PantallaGoogle extends StatefulWidget {
  const PantallaGoogle({super.key});

  @override
  State<PantallaGoogle> createState() => _PantallaGoogleState();
}

class _PantallaGoogleState extends State<PantallaGoogle> {
  int paso = 0; // 0 = elegir cuenta, 1 = permisos

  void entrar() {
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
                FilaItem(
                  titulo: 'Alexander Pino Caro',
                  subtitulo: 'alexpinocaro@gmail.com',
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
                const Encabezado('Claqueta quiere acceso', subtitulo: 'alexpinocaro@gmail.com'),
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
