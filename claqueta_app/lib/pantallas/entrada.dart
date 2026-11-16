import 'package:flutter/material.dart';
import '../tema.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'principal.dart';
import '../estilo.dart';

// Pantalla de entrada: logo, tagline y botón de Google.
// El inicio de sesión es SIMULADO: recorre los mismos pasos que Google
// (elegir cuenta y aceptar permisos) pero sin conectarse de verdad.
class PantallaEntrada extends StatelessWidget {
  const PantallaEntrada({super.key});

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
              TarjetaHero(
                relleno: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Paleta.suelo,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text('C', style: estiloDisplay(tamano: 32, color: Paleta.arena)),
                    ),
                    const SizedBox(height: 34),
                    Text('Claqueta', style: estiloDisplay(tamano: 36, color: Paleta.suelo)),
                    const SizedBox(height: 8),
                    Text(
                      'Cotiza, agenda y cobra tus producciones audiovisuales.',
                      style: TextStyle(
                          color: Paleta.suelo.withAlpha(200), fontSize: 14, height: 1.35),
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
              BotonClaqueta('Continuar con Google', () => ir(context, const PantallaGoogle()),
                  icono: Icons.login),
              const SizedBox(height: 12),
              Center(
                child: Text('Tus datos se guardan en este dispositivo', style: estiloSuave()),
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
                  subtitulo: 'Simulado en esta versión',
                  alTocar: () => mostrarAviso(context, 'Simulado: aquí se abre el selector de Google'),
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
                          'Usan la clave de la app. No se comparte tu ubicación.'),
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
        Icon(icono, color: Paleta.teal, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(texto, style: estiloSuave(tamano: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
