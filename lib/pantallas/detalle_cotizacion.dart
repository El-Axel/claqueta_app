import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'agendar_trabajo.dart';
import 'detalle_trabajo.dart';
import 'envio_cotizacion.dart';
import 'nueva_cotizacion.dart';
import 'pdf_vista.dart';
import '../pdf_documentos.dart';
import '../estilo.dart';

// Detalle de una cotización. Los botones cambian según el estado:
// Borrador -> enviar/editar/eliminar; Enviada -> aceptar/rechazar/recordar;
// Aceptada -> agendar el rodaje; Rechazada -> reabrir.
class DetalleCotizacion extends StatelessWidget {
  final int n;
  const DetalleCotizacion(this.n, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final c = tienda.cotizacion(n);
        if (c == null) {
          return Lienzo(
            appBar: barra('Cotización'),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: Vacio('Cotización no encontrada', 'Es posible que se haya eliminado.'),
            ),
          );
        }
        final cl = tienda.cliente(c.clienteId);
        final trabajo = tienda.trabajoDeCot(c.n);
        final diasEnviada = c.enviada == null ? 0 : diasDesde(c.enviada!);

        final acciones = <Widget>[];
        if (c.estado == estBorrador) {
          acciones.addAll([
            BotonClaqueta('Ver PDF y enviar', () => ir(context, EnvioCotizacion(c.n)),
                icono: Icons.send_outlined),
            BotonClaqueta('Editar', () => ir(context, NuevaCotizacion(editar: c)),
                tipo: 'secundario', icono: Icons.edit_outlined),
            BotonClaqueta('Duplicar', () => _duplicar(context, c),
                tipo: 'secundario', icono: Icons.copy_outlined),
            BotonClaqueta('Eliminar borrador', () => _eliminar(context, c),
                tipo: 'peligro', icono: Icons.delete_outline),
          ]);
        } else if (c.estado == estEnviada) {
          acciones.addAll([
            BotonClaqueta('Marcar como aceptada', () {
              tienda.cambiarEstado(c.n, estAceptada);
              mostrarAviso(context, 'Cotización aceptada. Ya puedes agendar el rodaje');
            }, tipo: 'arena', icono: Icons.check),
            BotonClaqueta(
              diasEnviada >= tienda.config.recordatorioDias ? 'Enviar recordatorio' : 'Reenviar',
              () => ir(context, EnvioCotizacion(c.n, recordatorio: true)),
              tipo: 'secundario',
              icono: Icons.notifications_active_outlined,
            ),
            BotonClaqueta('Duplicar', () => _duplicar(context, c),
                tipo: 'secundario', icono: Icons.copy_outlined),
            BotonClaqueta('Marcar como rechazada', () => tienda.cambiarEstado(c.n, estRechazada),
                tipo: 'peligro'),
          ]);
        } else if (c.estado == estAceptada) {
          acciones.add(trabajo != null
              ? BotonClaqueta('Ver trabajo agendado', () => ir(context, DetalleTrabajo(trabajo.id)),
                  icono: Icons.event_available_outlined)
              : BotonClaqueta('Agendar trabajo', () => ir(context, PantallaAgendar(cotN: c.n)),
                  icono: Icons.event_outlined));
          acciones.add(BotonClaqueta('Duplicar', () => _duplicar(context, c),
              tipo: 'secundario', icono: Icons.copy_outlined));
        } else {
          acciones.addAll([
            BotonClaqueta('Reabrir como borrador', () => tienda.cambiarEstado(c.n, estBorrador),
                tipo: 'secundario', icono: Icons.restart_alt),
            BotonClaqueta('Duplicar', () => _duplicar(context, c),
                tipo: 'secundario', icono: Icons.copy_outlined),
          ]);
        }

        return Lienzo(
          appBar: barra(folio(c.n), acciones: [
            IconButton(
              tooltip: 'Ver PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => ir(
                context,
                PdfVista(
                  titulo: folio(c.n),
                  archivo: '${folio(c.n)}.pdf',
                  construir: () => pdfCotizacion(c),
                ),
              ),
            ),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.proyecto, style: estiloDisplay(tamano: 18)),
                        const SizedBox(height: 4),
                        Text(cl.nombre, style: estiloSuave(tamano: 13)),
                      ],
                    ),
                  ),
                  Etiqueta(c.estado, color: coloresEstado[c.estado] ?? Paleta.teal),
                ],
              ),
              const SizedBox(height: 16),
              LineaEstado(c.estado),
              if (c.estado == estEnviada) ...[
                const SizedBox(height: 14),
                Aviso(
                  diasEnviada >= tienda.config.recordatorioDias
                      ? 'Enviada hace $diasEnviada días sin respuesta. Es buen momento de hacer seguimiento.'
                      : 'Enviada hace $diasEnviada días. Vigente hasta ${fechaCorta(c.vence)}.',
                  icono: Icons.schedule,
                  color: diasEnviada >= tienda.config.recordatorioDias ? Paleta.arena : Paleta.teal,
                ),
              ],
              const TituloSeccion('Detalle'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    for (final i in c.items)
                      FilaDato('${i.descripcion}${i.cantidad > 1 ? '  x${i.cantidad}' : ''}',
                          formatearPesos(i.subtotal),
                          colorValor: Paleta.arena),
                    if (c.descuento > 0)
                      FilaDato('Descuento ${c.descuento}%', '-${formatearPesos(c.valorDescuento)}',
                          colorValor: Paleta.durazno),
                    if (c.iva) FilaDato('IVA 19%', formatearPesos(c.valorIva)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total (COP)', style: TextStyle(fontWeight: FontWeight.w700)),
                  textoPesos(c.total),
                ],
              ),
              if (c.notas.isNotEmpty) ...[
                const TituloSeccion('Notas'),
                Text(c.notas, style: estiloSuave(tamano: 13)),
              ],
              const TituloSeccion('Cliente'),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    FilaDato('Correo', cl.correo.isEmpty ? 'Sin correo' : cl.correo),
                    FilaDato('Teléfono', cl.telefono.isEmpty ? 'Sin teléfono' : cl.telefono),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              for (final a in acciones) Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
            ],
          ),
        );
      },
    );
  }

  Future<void> _eliminar(BuildContext context, Cotizacion c) async {
    final ok = await confirmar(
      context,
      titulo: '¿Eliminar ${folio(c.n)}?',
      mensaje: 'Se borra este borrador. Esta acción no se puede deshacer.',
      boton: 'Eliminar',
      peligro: true,
    );
    if (ok && context.mounted) {
      tienda.eliminarCotizacion(c.n);
      Navigator.pop(context);
    }
  }

  void _duplicar(BuildContext context, Cotizacion c) {
    final nueva = tienda.duplicarCotizacion(c.n);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => DetalleCotizacion(nueva)));
  }
}
