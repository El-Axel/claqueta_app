import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tema.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'catalogo.dart';
import 'entrada.dart';
import '../estilo.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  static const _integraciones = [
    ['maps', 'Google Maps', 'Direcciones y mapa'],
    ['clima', 'Google Weather', 'Pronóstico del rodaje'],
    ['calendar', 'Google Calendar', 'Crear eventos'],
    ['gmail', 'Gmail', 'Solo enviar cotizaciones'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final cfg = tienda.config;
        return Lienzo(
          appBar: barra('Ajustes'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Panel(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Paleta.teal,
                      child: Text('A',
                          style: TextStyle(
                              color: Paleta.suelo, fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alexander Pino Caro',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          Text('alexpinocaro@gmail.com', style: estiloSuave(tamano: 13)),
                        ],
                      ),
                    ),
                    const Etiqueta('Conectado'),
                  ],
                ),
              ),
              const TituloSeccion('Integraciones'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final i in _integraciones)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i[1], style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(i[2], style: estiloSuave()),
                                ],
                              ),
                            ),
                            Switch(
                              value: tienda.integracion(i[0]),
                              activeColor: Paleta.teal,
                              onChanged: (v) => tienda.cambiarIntegracion(i[0], v),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'En esta versión las integraciones están simuladas. Al apagarlas verás cómo cambian las demás pantallas.',
                style: estiloSuave(tamano: 12),
              ),
              const TituloSeccion('Mi negocio'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _Linea(
                      'Nombre en cotizaciones',
                      cfg.negocio,
                      () => _editarTexto(context, 'Nombre en cotizaciones', cfg.negocio, (v) {
                        cfg.negocio = v;
                        tienda.guardarConfig();
                      }),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    _Linea(
                      'Mi WhatsApp',
                      cfg.telefono.isEmpty ? 'Sin definir' : cfg.telefono,
                      () => _editarTexto(context, 'Mi WhatsApp', cfg.telefono, (v) {
                        cfg.telefono = v;
                        tienda.guardarConfig();
                      }),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Incluir IVA 19% en cotizaciones nuevas',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Switch(
                            value: cfg.iva,
                            activeColor: Paleta.teal,
                            onChanged: (v) {
                              cfg.iva = v;
                              tienda.guardarConfig();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Vigencia de las cotizaciones (días)',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Cantidad(
                            valor: cfg.vigenciaDias,
                            minimo: 1,
                            paso: 5,
                            cambio: (v) {
                              cfg.vigenciaDias = v;
                              tienda.guardarConfig();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Recordar seguimiento tras (días)',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Cantidad(
                            valor: cfg.recordatorioDias,
                            minimo: 1,
                            cambio: (v) {
                              cfg.recordatorioDias = v;
                              tienda.guardarConfig();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Moneda', style: TextStyle(color: Paleta.tinta)),
                          Text('COP · Peso colombiano',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BotonClaqueta('Catálogo y paquetes', () => ir(context, const PantallaCatalogo()),
                  tipo: 'secundario', icono: Icons.inventory_2_outlined),
              const TituloSeccion('Copia de seguridad'),
              Text(
                'Tus datos viven solo en este dispositivo. Exporta una copia para no perderlos si borras los datos de la app.',
                style: estiloSuave(tamano: 13),
              ),
              const SizedBox(height: 10),
              BotonClaqueta('Exportar copia (copiar al portapapeles)', () async {
                await Clipboard.setData(ClipboardData(text: tienda.exportar()));
                if (context.mounted) {
                  mostrarAviso(context, 'Copia copiada. Pégala en un archivo o una nota');
                }
              }, tipo: 'secundario', icono: Icons.upload_outlined),
              const SizedBox(height: 10),
              BotonClaqueta('Restaurar desde una copia', () => _restaurar(context),
                  tipo: 'secundario', icono: Icons.download_outlined),
              const TituloSeccion('Datos y sesión'),
              BotonClaqueta('Restablecer datos de ejemplo', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Restablecer datos?',
                  mensaje: 'Se reemplaza todo por los datos de ejemplo. Exporta una copia antes si la necesitas.',
                  boton: 'Restablecer',
                  peligro: true,
                );
                if (ok && context.mounted) {
                  tienda.restablecer();
                  mostrarAviso(context, 'Datos de ejemplo restablecidos');
                }
              }, tipo: 'secundario', icono: Icons.restart_alt),
              const SizedBox(height: 10),
              BotonClaqueta('Cerrar sesión', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Cerrar sesión?',
                  mensaje: 'Tus datos siguen guardados en este dispositivo.',
                  boton: 'Cerrar sesión',
                  peligro: true,
                );
                if (ok && context.mounted) {
                  tienda.cerrarSesion();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaEntrada()),
                    (ruta) => false,
                  );
                }
              }, tipo: 'peligro', icono: Icons.logout),
              const SizedBox(height: 20),
              Center(child: Text('Claqueta v0.2 · avance de proyecto', style: estiloSuave())),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editarTexto(
      BuildContext context, String titulo, String actual, void Function(String) guardar) async {
    final c = TextEditingController(text: actual);
    final ok = await hojaInferior<bool>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 14),
          TextField(controller: c, decoration: decoracionCampo(titulo)),
          const SizedBox(height: 16),
          BotonClaqueta('Guardar', () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    final texto = c.text.trim();
    if (ok == true && texto.isNotEmpty) guardar(texto);
  }

  Future<void> _restaurar(BuildContext context) async {
    final c = TextEditingController();
    final ok = await hojaInferior<bool>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Restaurar copia', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 4),
          Text('Pega aquí el texto de tu copia. Reemplaza los datos actuales.',
              style: estiloSuave(tamano: 13)),
          const SizedBox(height: 14),
          TextField(controller: c, maxLines: 6, decoration: decoracionCampo('Copia (JSON)')),
          const SizedBox(height: 16),
          BotonClaqueta('Restaurar', () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    final texto = c.text;
    if (ok != true || !context.mounted) return;
    final bien = tienda.importar(texto);
    mostrarAviso(context, bien ? 'Copia restaurada' : 'No se pudo leer esa copia');
  }
}

class _Linea extends StatelessWidget {
  final String titulo;
  final String valor;
  final VoidCallback alTocar;
  const _Linea(this.titulo, this.valor, this.alTocar);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloSuave(tamano: 13)),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
