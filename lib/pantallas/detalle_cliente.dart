import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../compartir.dart';
import '../modelos.dart';
import '../servicios/nube.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_cotizacion.dart';
import 'detalle_trabajo.dart';
import 'formulario_cliente.dart';
import 'nueva_cotizacion.dart';
import '../estilo.dart';

class DetalleCliente extends StatelessWidget {
  final int id;
  const DetalleCliente(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final matches = tienda.clientes.where((c) => c.id == id);
        if (matches.isEmpty) {
          return Lienzo(
            appBar: barra('Cliente'),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: Vacio('Cliente no encontrado', 'Es posible que se haya eliminado.'),
            ),
          );
        }
        final c = matches.first;
        final cots = tienda.cotizaciones.where((x) => x.clienteId == c.id).toList()
          ..sort((a, b) => b.n.compareTo(a.n));
        final trabajos = tienda.trabajos.where((t) => t.clienteId == c.id).toList();
        final aceptado = cots
            .where((x) => x.estado == estAceptada)
            .fold<int>(0, (a, x) => a + x.total);

        return Lienzo(
          appBar: barra('Cliente', acciones: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => ir(context, FormularioCliente(editar: c)),
            ),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
            children: [
              Center(child: Ficha(inicialDe(c.nombre), tamano: 84, redonda: true)),
              const SizedBox(height: 14),
              // Nombre con el estilo del saludo del Home (Figtree en negrita).
              Center(
                  child: Text(c.nombre,
                      style: estiloTituloPantalla(), textAlign: TextAlign.center)),
              const SizedBox(height: 22),
              // Cifras en tinta y solo lo cobrable (Aceptado) en arena:
              // antes cada cifra tenía un color distinto.
              TarjetaSuave(
                relleno: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                child: Estadisticas(
                  [
                    ['${cots.length}', 'Cotizaciones'],
                    [pesosCortos(aceptado), 'Aceptado'],
                    ['${trabajos.length}', 'Trabajos'],
                  ],
                  colores: const [Paleta.tinta, Paleta.arena, Paleta.tinta],
                ),
              ),
              const SizedBox(height: 10),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    FilaDato('Correo', c.correo.isEmpty ? 'Sin correo' : c.correo),
                    FilaDato('Teléfono', c.telefono.isEmpty ? 'Sin teléfono' : c.telefono),
                    if (c.notas.isNotEmpty) FilaDato('Notas', c.notas),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BotonClaqueta('WhatsApp', () async {
                      final ok = await abrirWhatsApp(c.telefono, 'Hola ${c.nombre}, ');
                      if (!ok && context.mounted) {
                        mostrarAviso(context, 'No se pudo abrir WhatsApp (revisa el teléfono)');
                      }
                    }, tipo: 'secundario', icono: Icons.chat_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BotonClaqueta('Correo', () async {
                      final ok = await abrirCorreo(c.correo, 'Hola ${c.nombre}', '');
                      if (!ok && context.mounted) {
                        mostrarAviso(context, 'No se pudo abrir el correo (revisa la dirección)');
                      }
                    }, tipo: 'secundario', icono: Icons.mail_outline),
                  ),
                ],
              ),
              // Código para que el cliente entre a su espacio en la app.
              if (c.codigo.isNotEmpty) ...[
                const TituloSeccion('Acceso del cliente'),
                TarjetaSuave(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.codigo,
                          style: estiloDisplay(tamano: 22, color: Paleta.arena)),
                      const SizedBox(height: 6),
                      Text(
                        'Con este código ${c.nombre} entra a Claqueta como cliente: ve sus cotizaciones, '
                        'responde, pide cotizaciones nuevas y recibe novedades.',
                        style: estiloSuave(tamano: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: c.codigo));
                              if (context.mounted) mostrarAviso(context, 'Código copiado');
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copiar'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final ok = await abrirWhatsApp(c.telefono, mensajeInvitacion(c, tienda.config));
                              if (!ok && context.mounted) {
                                mostrarAviso(context, 'No se pudo abrir WhatsApp (revisa el teléfono)');
                              }
                            },
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('Enviar por WhatsApp'),
                          ),
                          TextButton.icon(
                            onPressed: () => _cambiarCodigo(context, c),
                            icon: const Icon(Icons.lock_reset, size: 18),
                            label: const Text('Cambiar código'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const TituloSeccion('Cotizaciones'),
              if (cots.isEmpty)
                const Vacio('Sin cotizaciones', 'Crea la primera para este cliente.')
              else
                for (final x in cots) FilaCot(x, alTocar: () => ir(context, DetalleCotizacion(x.n))),
              if (trabajos.isNotEmpty) ...[
                const TituloSeccion('Trabajos'),
                for (final t in trabajos)
                  FilaTrabajo(t, alTocar: () => ir(context, DetalleTrabajo(t.id))),
              ],
              const SizedBox(height: 14),
              BotonClaqueta('Nueva cotización', () => ir(context, NuevaCotizacion(clienteId: c.id))),
              const SizedBox(height: 10),
              BotonClaqueta('Eliminar cliente', () async {
                final ok = await confirmar(
                  context,
                  titulo: '¿Eliminar a ${c.nombre}?',
                  mensaje: 'Solo se puede si no tiene cotizaciones ni trabajos.',
                  boton: 'Eliminar',
                  peligro: true,
                );
                if (!ok || !context.mounted) return;
                if (tienda.eliminarCliente(c.id)) {
                  Navigator.pop(context);
                } else {
                  mostrarAviso(context, 'No se puede: tiene cotizaciones o trabajos');
                }
              }, tipo: 'peligro', icono: Icons.delete_outline),
            ],
          ),
        );
      },
    );
  }
}

/// Cambia el código del cliente y saca a quien hubiera entrado con el
/// anterior (útil si el código se filtró o se envió a otra persona).
Future<void> _cambiarCodigo(BuildContext context, Cliente c) async {
  final ok = await confirmar(
    context,
    titulo: '¿Cambiar el código de ${c.nombre}?',
    mensaje: 'El código actual deja de servir y quien haya entrado con él sale de su espacio. '
        'Luego envíale el código nuevo.',
    boton: 'Cambiar código',
    peligro: true,
  );
  if (!ok || !context.mounted) return;
  tienda.cambiarCodigo(c.id);
  try {
    if (servicioNube.conectada) {
      await servicioNube.subir(); // el código viejo deja de existir en la nube
      await servicioNube.revocarAccesos(c.id);
    }
    if (context.mounted) mostrarAviso(context, 'Código nuevo: ${tienda.cliente(c.id).codigo}');
  } catch (e) {
    if (context.mounted) {
      mostrarAviso(context, 'Código cambiado en el teléfono; la nube se actualizará al conectar');
    }
  }
}
