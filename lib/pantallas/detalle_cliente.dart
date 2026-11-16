import 'package:flutter/material.dart';
import '../compartir.dart';
import '../modelos.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(child: Ficha(inicialDe(c.nombre), tamano: 88)),
              const SizedBox(height: 12),
              Center(child: Text(c.nombre, style: estiloDisplay(tamano: 18), textAlign: TextAlign.center)),
              const SizedBox(height: 16),
              Panel(
                relleno: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Estadisticas(
                  [
                    ['${cots.length}', 'Cotizaciones'],
                    [pesosCortos(aceptado), 'Aceptado'],
                    ['${trabajos.length}', 'Trabajos'],
                  ],
                  colores: const [Paleta.teal, Paleta.arena, Paleta.durazno],
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
