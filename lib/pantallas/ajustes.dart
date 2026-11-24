import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servicios/google_api.dart';
import '../servicios/nube.dart';
import '../selectores.dart';
import '../servicios/ubicacion.dart';
import '../tema.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'catalogo.dart';
import 'cuenta.dart';
import 'entrada.dart';
import '../estilo.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  static const _integraciones = [
    ['maps', 'Mapa (OpenStreetMap)', 'Buscar direcciones y ver el lugar'],
    ['clima', 'Clima (Open-Meteo)', 'Pronóstico real a 16 días'],
    ['calendar', 'Google Calendar', 'Crear eventos de rodaje'],
    ['gmail', 'Gmail', 'Solo enviar cotizaciones'],
  ];

  Future<void> _desconectarGoogle(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: '¿Quitar Google?',
      mensaje: 'Tu cuenta y tus datos siguen igual. Solo se deja de enviar por Gmail y de agendar en Calendar.',
      boton: 'Quitar',
    );
    if (!ok) return;
    await servicioGoogle.salir().catchError((_) {});
    if (context.mounted) mostrarAviso(context, 'Google desconectado');
  }

  /// Pone o cambia la contraseña (útil si entraste con Google).
  Future<void> _cambiarClave(BuildContext context) async {
    final c = TextEditingController();
    final clave = await hojaInferior<String>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nueva contraseña', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 4),
          Text('Con ella entras con ${servicioNube.correo} en cualquier teléfono.',
              style: estiloSuave(tamano: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            obscureText: true,
            decoration: decoracionCampo('Contraseña', ayuda: 'Mínimo 6 caracteres'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 14),
          BotonClaqueta('Guardar contraseña', () => Navigator.pop(ctx, c.text)),
        ],
      ),
    );
    if (clave == null || !context.mounted) return;
    if (clave.length < 6) {
      mostrarAviso(context, 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    await _accionNube(context, () => servicioNube.cambiarClave(clave), 'Contraseña guardada');
  }

  Future<void> _conectarGoogle(BuildContext context) async {
    try {
      await servicioGoogle.entrar();
      if (context.mounted) mostrarAviso(context, 'Conectado como ${servicioGoogle.correo}');
    } catch (e) {
      if (context.mounted) mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tienda, servicioGoogle, servicioNube]),
      builder: (context, _) {
        final cfg = tienda.config;
        final g = servicioGoogle;
        // La identidad es la CUENTA de Claqueta; Google es solo una conexión.
        final n = servicioNube;
        final nombre = n.nombreCuenta.isNotEmpty
            ? n.nombreCuenta
            : cfg.negocio.isNotEmpty && cfg.negocio != 'Mi negocio'
                ? cfg.negocio
                : g.conectado && g.nombre.isNotEmpty
                    ? g.nombre
                    : 'Tu cuenta';
        return Lienzo(
          appBar: barra('Ajustes'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
            children: [
              // Perfil en tarjeta suave, con la misma ficha redonda del avatar
              // del Home (antes un círculo teal sólido).
              TarjetaSuave(
                relleno: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Ficha(nombre[0].toUpperCase(), tamano: 48, redonda: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(
                              n.conectada
                                  ? n.correo
                                  : n.configurada
                                      ? 'Sin cuenta abierta'
                                      : 'Modo demostración',
                              overflow: TextOverflow.ellipsis,
                              style: estiloSuave(tamano: 13)),
                        ],
                      ),
                    ),
                    if (n.conectada)
                      const Etiqueta('Cuenta')
                    else if (n.configurada)
                      TextButton(
                          onPressed: () => ir(context, const PantallaCuenta(crear: false)),
                          child: const Text('Entrar'))
                    else
                      Etiqueta('Demo', color: Paleta.tinta.withAlpha(150)),
                  ],
                ),
              ),
              // ---------- Google: solo para Gmail y Calendar ----------
              const TituloSeccion('Google (Gmail y Calendar)'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.g_mobiledata, size: 28, color: Paleta.arena),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.conectado ? g.correo : 'Sin conectar',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              g.real
                                  ? 'Para enviar cotizaciones por Gmail y agendar en Calendar. Puede ser un correo distinto al de tu cuenta.'
                                  : 'Modo demostración: Google no está configurado en esta versión.',
                              style: estiloSuave(tamano: 12)),
                        ],
                      ),
                    ),
                    if (g.conectado)
                      TextButton(
                          onPressed: () => _desconectarGoogle(context),
                          child: const Text('Quitar'))
                    else if (g.real)
                      TextButton(
                          onPressed: () => _conectarGoogle(context), child: const Text('Conectar')),
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
                                  Text(i[2], style: estiloSuave(tamano: 13)),
                                ],
                              ),
                            ),
                            // Color del interruptor: lo pone el tema (arena).
                            Switch(
                              value: tienda.integracion(i[0]),
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
                servicioGoogle.real
                    ? 'Mapa y clima son gratuitos y no piden cuenta. Gmail y Calendar usan tu cuenta de Google con permisos mínimos.'
                    : 'Mapa y clima son reales. Gmail y Calendar están en modo demostración hasta configurar Google.',
                style: estiloSuave(tamano: 12),
              ),
              // ---------- Nube (Supabase) ----------
              const TituloSeccion('Nube'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          servicioNube.estado == EstadoNube.alDia
                              ? Icons.cloud_done_outlined
                              : servicioNube.estado == EstadoNube.error
                                  ? Icons.cloud_off_outlined
                                  : Icons.cloud_outlined,
                          size: 20,
                          color: servicioNube.estado == EstadoNube.alDia
                              ? Paleta.arena
                              : Paleta.tinta.withAlpha(150),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_textoNube(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      servicioNube.configurada
                          ? 'Tus datos se guardan en el teléfono y una copia en Supabase. Si reinstalas la app, los recuperas al iniciar sesión.'
                          : 'Esta versión no tiene Supabase configurado: los datos solo están en el teléfono.',
                      style: estiloSuave(tamano: 12),
                    ),
                    if (servicioNube.configurada) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (!servicioNube.conectada)
                            TextButton.icon(
                              onPressed: () => ir(context, const PantallaCuenta(crear: false)),
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('Entrar a mi cuenta'),
                            )
                          else ...[
                            TextButton.icon(
                              onPressed: servicioNube.estado == EstadoNube.sincronizando
                                  ? null
                                  : () => _accionNube(context, servicioNube.subir, 'Copia actualizada en la nube'),
                              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                              label: const Text('Guardar ahora'),
                            ),
                            TextButton.icon(
                              onPressed: servicioNube.estado == EstadoNube.sincronizando
                                  ? null
                                  : () => _traerDeNube(context),
                              icon: const Icon(Icons.cloud_download_outlined, size: 18),
                              label: const Text('Traer de la nube'),
                            ),
                            TextButton.icon(
                              onPressed: () => _cambiarClave(context),
                              icon: const Icon(Icons.password_outlined, size: 18),
                              label: const Text('Contraseña'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const TituloSeccion('Zona de búsqueda'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _Linea(
                      'Ciudad',
                      cfg.ciudad.isEmpty ? 'Toda Colombia' : cfg.ciudad,
                      () => _elegirCiudad(context),
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          try {
                            final c = await usarMiUbicacion();
                            if (context.mounted) mostrarAviso(context, 'Zona: $c');
                          } catch (e) {
                            if (context.mounted) {
                              await elegirCiudad(context,
                                  motivo: e.toString().replaceFirst('Exception: ', ''));
                            }
                          }
                        },
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Usar mi ubicación aproximada'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Al buscar direcciones salen primero los lugares de tu ciudad. También define el clima del Inicio.',
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
                    const Divider(height: 8),
                    _Linea(
                      'Mi WhatsApp',
                      cfg.telefono.isEmpty ? 'Sin definir' : cfg.telefono,
                      () => _editarTexto(context, 'Mi WhatsApp', cfg.telefono, (v) {
                        cfg.telefono = v;
                        tienda.guardarConfig();
                      }),
                    ),
                    const Divider(height: 8),
                    // Sale en el pie de los correos de cotización.
                    _Linea(
                      'Mi sitio web',
                      cfg.web.isEmpty ? 'Sin definir' : cfg.web,
                      () => _editarTexto(context, 'Mi sitio web', cfg.web, (v) {
                        cfg.web = v;
                        tienda.guardarConfig();
                      }),
                    ),
                    const Divider(height: 8),
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
                            onChanged: (v) {
                              cfg.iva = v;
                              tienda.guardarConfig();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 8),
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
                    const Divider(height: 8),
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
                    const Divider(height: 8),
                    // Arreglo del desborde a 390 px: los dos textos estaban
                    // sueltos en la Row y juntos no cabían. Con Expanded/Flexible
                    // cada uno toma su parte y el valor se corta con "…".
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Moneda', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text('COP · Peso colombiano',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: estiloSuave(tamano: 13)),
                          ),
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
                servicioNube.conectada
                    ? 'Tus datos ya se guardan en tu cuenta. Además puedes exportar una copia en texto.'
                    : 'Tus datos viven solo en este dispositivo. Exporta una copia para no perderlos si borras los datos de la app.',
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
              // Datos de ejemplo: para mostrar la app (por ejemplo en la
              // sustentación) sin tener que inventar clientes a mano.
              BotonClaqueta('Cargar datos de ejemplo', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Cargar datos de ejemplo?',
                  mensaje: 'Tus clientes, catálogo, cotizaciones y trabajos se REEMPLAZAN por datos '
                      'de ejemplo${servicioNube.conectada ? ' (también en la nube)' : ''}. '
                      'Exporta una copia antes si la necesitas.',
                  boton: 'Cargar ejemplos',
                  peligro: true,
                );
                if (ok && context.mounted) {
                  tienda.cargarEjemplos();
                  mostrarAviso(context, 'Datos de ejemplo cargados');
                }
              }, tipo: 'secundario', icono: Icons.auto_awesome_outlined),
              const SizedBox(height: 10),
              BotonClaqueta('Borrar todos mis datos', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Borrar todos tus datos?',
                  mensaje: 'Se borran clientes, catálogo, cotizaciones y trabajos'
                      '${servicioNube.conectada ? ', también en la nube' : ''}. '
                      'Tus ajustes del negocio se conservan. No se puede deshacer.',
                  boton: 'Borrar todo',
                  peligro: true,
                );
                if (ok && context.mounted) {
                  tienda.borrarTodo();
                  mostrarAviso(context, 'Listo: la app quedó en blanco');
                }
              }, tipo: 'peligro', icono: Icons.delete_sweep_outlined),
              const SizedBox(height: 10),
              BotonClaqueta('Cerrar sesión', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Cerrar sesión?',
                  mensaje: servicioNube.conectada
                      ? 'Tus datos quedan guardados en tu cuenta. Para volver, entra de nuevo con tu cuenta.'
                      : 'Tus datos siguen guardados en este dispositivo.',
                  boton: 'Cerrar sesión',
                  peligro: true,
                );
                if (ok && context.mounted) {
                  tienda.cerrarSesion();
                  servicioNube.desconectar().catchError((_) {});
                  servicioGoogle.salir().catchError((_) {});
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaEntrada()),
                    (ruta) => false,
                  );
                }
              }, tipo: 'peligro', icono: Icons.logout),
              const SizedBox(height: 20),
              Center(child: Text('Claqueta 1.0.3', style: estiloSuave())),
            ],
          ),
        );
      },
    );
  }

  String _textoNube() {
    final n = servicioNube;
    switch (n.estado) {
      case EstadoNube.sinConfigurar:
        return 'Solo en este teléfono';
      case EstadoNube.desconectado:
        return 'Nube sin conectar';
      case EstadoNube.sincronizando:
        return 'Guardando en la nube…';
      case EstadoNube.error:
        return 'No se pudo sincronizar';
      case EstadoNube.alDia:
        final h = n.ultimaSubida;
        return h == null
            ? 'Conectada${n.correo.isEmpty ? '' : ' · ${n.correo}'}'
            : 'Al día · ${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _accionNube(BuildContext context, Future<void> Function() accion, String ok) async {
    try {
      await accion();
      if (context.mounted) mostrarAviso(context, ok);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'Nube: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _traerDeNube(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Traer datos de la nube',
      mensaje: 'Los datos de este teléfono se reemplazan por la copia guardada en Supabase.',
      boton: 'Traer',
    );
    if (ok && context.mounted) {
      await _accionNube(context, servicioNube.bajar, 'Datos recuperados de la nube');
    }
  }

  /// Escribir la ciudad a mano (si no quieres dar permiso de ubicación).
  Future<void> _elegirCiudad(BuildContext context) => elegirCiudad(context);

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
