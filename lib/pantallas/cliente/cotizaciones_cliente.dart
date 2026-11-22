import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../modelos.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../util.dart';
import '../../widgets.dart';
import 'piezas_cliente.dart';
import 'rodaje_cliente.dart';

// ---------------------------------------------------------------
// COTIZACIONES DEL CLIENTE: lista y detalle. El cliente no edita la
// cotización; solo la acepta o pide cambios. Esa respuesta se guarda
// aparte (tabla respuestas) y el realizador la aplica desde su app.
// ---------------------------------------------------------------

class PestanaCotizacionesCliente extends StatelessWidget {
  const PestanaCotizacionesCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: portal,
      builder: (context, _) {
        final lista = [...portal.cotizaciones]..sort((a, b) => b.n.compareTo(a.n));
        final porResponder = cotizacionesPorResponder().length;
        return ListaPortal([
          CabeceraCliente(
            'Cotizaciones',
            subtitulo: porResponder == 0
                ? 'Las propuestas que te envió ${nombreRealizador()}'
                : (porResponder == 1
                    ? '1 espera tu respuesta'
                    : '$porResponder esperan tu respuesta'),
          ),
          const EstadoPortal(),
          if (portal.cargando && lista.isEmpty)
            const CargandoPortal(texto: 'Buscando tus cotizaciones…')
          else if (lista.isEmpty)
            const Vacio('Aún no tienes cotizaciones',
                'Cuando tu realizador te envíe una, aparecerá aquí. También puedes pedirla en Solicitar.')
          else
            for (final c in lista)
              FilaCotCliente(c, alTocar: () => ir(context, DetalleCotizacionCliente(c.n))),
        ]);
      },
    );
  }
}

/// Detalle de una cotización. Recibe el número y la busca en el portal
/// cada vez que cambia, así refleja al instante la respuesta enviada.
class DetalleCotizacionCliente extends StatefulWidget {
  final int n;
  const DetalleCotizacionCliente(this.n, {super.key});

  @override
  State<DetalleCotizacionCliente> createState() => _DetalleCotizacionClienteState();
}

class _DetalleCotizacionClienteState extends State<DetalleCotizacionCliente> {
  bool _enviando = false;

  Cotizacion? get _cot {
    for (final c in portal.cotizaciones) {
      if (c.n == widget.n) return c;
    }
    return null;
  }

  Future<void> _aceptar(Cotizacion c) async {
    final ok = await confirmar(
      context,
      titulo: 'Aceptar cotización',
      mensaje:
          'Le avisaremos a ${nombreRealizador()} que aceptas "${c.proyecto}" por ${formatearPesos(c.total)}.',
      boton: 'Aceptar',
    );
    if (!ok) return;
    await _enviar(() => portal.responder(c.n, 'aceptar'),
        'Listo. ${nombreRealizador()} recibirá tu aceptación.');
  }

  Future<void> _pedirCambios(Cotizacion c) async {
    final mensaje = await hojaInferior<String>(context, (ctx) => const _HojaCambios());
    if (mensaje == null || mensaje.trim().isEmpty) return;
    await _enviar(() => portal.responder(c.n, 'cambios', mensaje: mensaje),
        'Enviado. ${nombreRealizador()} revisará tus cambios.');
  }

  Future<void> _enviar(Future<void> Function() accion, String exito) async {
    setState(() => _enviando = true);
    try {
      await accion();
      if (mounted) mostrarAviso(context, exito);
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra(folio(widget.n)),
      body: ListenableBuilder(
        listenable: portal,
        builder: (context, _) {
          final c = _cot;
          if (c == null) {
            return Pagina([
              const EstadoPortal(),
              const Vacio('Cotización no disponible',
                  'Puede que tu realizador la haya retirado. Desliza en la lista para actualizar.'),
            ]);
          }
          return Pagina([
            const EstadoPortal(),
            Text(c.proyecto, style: estiloTituloPantalla()),
            const SizedBox(height: 6),
            Text('${nombreRealizador()} · ${fechaLarga(c.enviada ?? c.creada)}',
                style: estiloSuave(tamano: 14)),
            const SizedBox(height: 18),
            LineaEstado(c.estado),
            const SizedBox(height: 22),

            // ---- Ítems ----
            TarjetaSuave(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetaSeccion('Qué incluye'),
                  const SizedBox(height: 12),
                  for (final i in c.items) _FilaItemCot(i),
                  Divider(height: 22, color: Colors.white.withAlpha(20)),
                  FilaDato('Subtotal', formatearPesos(c.subtotal)),
                  if (c.valorDescuento > 0)
                    FilaDato('Descuento (${c.descuento}%)', '-${formatearPesos(c.valorDescuento)}',
                        colorValor: Paleta.teal),
                  if (c.valorIva > 0) FilaDato('IVA (19%)', formatearPesos(c.valorIva)),
                  const SizedBox(height: 14),
                  const EtiquetaSeccion('Total'),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: textoPesos(c.total, tamano: 28),
                  ),
                  const SizedBox(height: 10),
                  DatoLinea(Icons.event_available_outlined, 'Válida hasta ${fechaLarga(c.vence)}'),
                ],
              ),
            ),
            if (c.notas.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Notas'),
                    const SizedBox(height: 8),
                    Text(c.notas, style: TextStyle(color: Paleta.tinta.withAlpha(215), height: 1.35)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            ..._acciones(c),
          ]);
        },
      ),
    );
  }

  /// Lo que se muestra abajo según el estado de la cotización.
  List<Widget> _acciones(Cotizacion c) {
    final respuesta = portal.respuestaPendiente(c.n);
    if (c.estado == estEnviada && respuesta != null) {
      final acepto = respuesta['accion'] == 'aceptar';
      final mensaje = (respuesta['mensaje'] as String?)?.trim() ?? '';
      final cuando = fechaDeTexto(respuesta['creada']);
      return [
        Panel(
          color: Paleta.arena,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_send_outlined, color: Paleta.arena, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Respuesta enviada · esperando a ${nombreRealizador()}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                acepto ? 'Aceptaste esta cotización.' : 'Pediste cambios:',
                style: estiloSuave(tamano: 13),
              ),
              if (mensaje.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('"$mensaje"',
                    style: TextStyle(color: Paleta.tinta.withAlpha(220), height: 1.35)),
              ],
              if (cuando != null) ...[
                const SizedBox(height: 8),
                Text('Enviada ${fechaRelativa(cuando)}', style: estiloSuave(tamano: 12)),
              ],
            ],
          ),
        ),
      ];
    }
    if (c.estado == estEnviada) {
      return [
        BotonClaqueta(
          _enviando ? 'Enviando…' : 'Aceptar cotización',
          _enviando ? null : () => _aceptar(c),
          icono: Icons.check_rounded,
        ),
        const SizedBox(height: 10),
        BotonClaqueta(
          'Pedir cambios',
          _enviando ? null : () => _pedirCambios(c),
          tipo: 'secundario',
          icono: Icons.edit_note_rounded,
        ),
      ];
    }
    if (c.estado == estAceptada) {
      Trabajo? rodaje;
      for (final t in portal.trabajos) {
        if (t.cotN == c.n) rodaje = t;
      }
      return [
        Panel(
          color: Paleta.teal,
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, color: Paleta.teal),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aceptada ✓',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
        if (rodaje != null) ...[
          const TituloSeccion('Tu rodaje'),
          FilaRodajeCliente(rodaje,
              alTocar: () => ir(context, DetalleRodajeCliente(rodaje!.id))),
        ] else ...[
          const SizedBox(height: 10),
          Text('${nombreRealizador()} agendará el rodaje pronto.',
              style: estiloSuave(tamano: 13)),
        ],
      ];
    }
    if (c.estado == estRechazada) {
      return [
        Panel(
          color: Paleta.terracota,
          child: Row(
            children: [
              const Icon(Icons.block_outlined, color: Paleta.terracota),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Esta cotización quedó rechazada.',
                    style: TextStyle(color: Paleta.tinta.withAlpha(220), fontSize: 14)),
              ),
            ],
          ),
        ),
      ];
    }
    return const [];
  }
}

/// Renglón de un ítem: "Descripción × 2" y su subtotal.
class _FilaItemCot extends StatelessWidget {
  final ItemCot i;
  const _FilaItemCot(this.i);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.descripcion,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${formatearPesos(i.precio)} × ${i.cantidad} ${i.unidad}',
                    style: estiloSuave(tamano: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatearPesos(i.subtotal),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Hoja "Pedir cambios": el mensaje es obligatorio (sin él el realizador
/// no sabría qué ajustar), por eso el botón espera a que haya texto.
class _HojaCambios extends StatefulWidget {
  const _HojaCambios();

  @override
  State<_HojaCambios> createState() => _HojaCambiosState();
}

class _HojaCambiosState extends State<_HojaCambios> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _texto.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pedir cambios', style: estiloDisplay(tamano: 16)),
        const SizedBox(height: 4),
        Text('Cuéntale a ${nombreRealizador()} qué quieres ajustar.',
            style: estiloSuave(tamano: 13)),
        const SizedBox(height: 14),
        TextField(
          controller: _texto,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoracionCampo('Tu mensaje',
              ayuda: 'Ej.: ¿Podemos quitar el dron y sumar una hora más?'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        BotonClaqueta('Enviar cambios', listo ? () => Navigator.pop(context, _texto.text) : null,
            icono: Icons.send_rounded),
      ],
    );
  }
}
