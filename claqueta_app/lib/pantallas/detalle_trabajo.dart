import 'package:flutter/material.dart';
import '../compartir.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_cotizacion.dart';
import '../estilo.dart';

// Todo sobre un rodaje: datos, mapa, clima, pagos y plan B.
class DetalleTrabajo extends StatelessWidget {
  final int id;
  const DetalleTrabajo(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final t = tienda.trabajo(id);
        if (t == null) {
          return Lienzo(
            appBar: barra('Trabajo'),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: Vacio('Trabajo no encontrado', 'Es posible que se haya cancelado.'),
            ),
          );
        }
        final cl = tienda.cliente(t.clienteId);
        final progreso = t.valor == 0 ? 0.0 : t.pagado / t.valor;
        final cruces = tienda.conflictosPara(t.fecha, t.hora, ignorarId: t.id);
        final hoy = soloFecha(DateTime.now());
        final futuro = !soloFecha(t.fecha).isBefore(hoy);
        final planB = futuro && tienda.integracion('clima') && climaDe(t.fecha).riesgoLluvia
            ? tienda.alternativas(t.fecha, t.hora, ignorarId: t.id)
            : <DateTime>[];

        String estadoPago = 'Pendiente';
        Color colorPago = Paleta.arena;
        if (t.valor > 0 && t.pagado >= t.valor) {
          estadoPago = 'Pagado';
          colorPago = Paleta.teal;
        } else if (t.pagado > 0) {
          estadoPago = 'Parcial';
          colorPago = Paleta.durazno;
        }

        return Lienzo(
          appBar: barra('Trabajo'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(t.titulo, style: estiloDisplay(tamano: 18)),
              const SizedBox(height: 4),
              Text('${fechaLarga(t.fecha)} · ${hora12(t.hora)}', style: estiloSuave(tamano: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Etiqueta(futuro ? 'Confirmado' : 'Realizado'),
                  Etiqueta(t.enCalendar ? 'En Calendar' : 'Sin Calendar',
                      color: t.enCalendar ? Paleta.arena : Paleta.petroleo),
                  if (t.invitaCliente) const Etiqueta('Cliente invitado', color: Paleta.durazno),
                ],
              ),
              const SizedBox(height: 14),
              Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    FilaDato('Cliente', cl.nombre),
                    FilaDato('Lugar', t.lugar),
                    FilaDato('Valor', formatearPesos(t.valor), colorValor: Paleta.arena),
                    if (t.cotN != null) FilaDato('Cotización', folio(t.cotN!)),
                  ],
                ),
              ),
              if (cruces.isNotEmpty) ...[
                const SizedBox(height: 12),
                Aviso(
                  'Se cruza con: ${cruces.map((x) => x.titulo).join(', ')}.',
                  icono: Icons.warning_amber_rounded,
                  color: Paleta.terracota,
                ),
              ],
              const SizedBox(height: 12),
              MapaSimulado(t.lugar, zona: t.zona),
              const SizedBox(height: 12),
              TarjetaClima(t.fecha),
              if (planB.isNotEmpty) ...[
                const TituloSeccion('Plan B por lluvia'),
                Text('Fechas cercanas con poca lluvia y sin cruces:', style: estiloSuave(tamano: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in planB)
                      ActionChip(
                        avatar: Icon(climaDe(d).icono, size: 16, color: Paleta.arena),
                        label: Text('${fechaCorta(d)} · ${climaDe(d).temperatura}°'),
                        backgroundColor: Colors.white.withAlpha(18),
                        side: BorderSide(color: Colors.white.withAlpha(50)),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                        onPressed: () => _reprogramar(context, t, d),
                      ),
                  ],
                ),
              ],
              const TituloSeccion('Pagos'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${formatearPesos(t.pagado)} de ${formatearPesos(t.valor)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Etiqueta(estadoPago, color: colorPago),
                      ],
                    ),
                    const SizedBox(height: 10),
                    BarraProgreso(progreso),
                    const SizedBox(height: 10),
                    if (t.pagos.isEmpty)
                      Text('Aún no hay pagos registrados.', style: estiloSuave(tamano: 13))
                    else
                      for (final p in t.pagos)
                        FilaDato('${p.tipo} · ${p.metodo} · ${fechaCorta(p.fecha)}',
                            formatearPesos(p.monto),
                            colorValor: Paleta.arena),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (t.pendiente > 0) ...[
                BotonClaqueta('Registrar pago', () => _registrarPago(context, t),
                    tipo: 'arena', icono: Icons.payments_outlined),
                const SizedBox(height: 10),
              ],
              BotonClaqueta('Avisar al cliente por WhatsApp', () async {
                final ok = await abrirWhatsApp(cl.telefono, mensajeAgenda(t, cl, tienda.config));
                if (!ok && context.mounted) {
                  mostrarAviso(context, 'No se pudo abrir WhatsApp (revisa el teléfono del cliente)');
                }
              }, tipo: 'secundario', icono: Icons.chat_outlined),
              if (t.cotN != null && tienda.cotizacion(t.cotN!) != null) ...[
                const SizedBox(height: 10),
                BotonClaqueta('Ver cotización', () => ir(context, DetalleCotizacion(t.cotN!)),
                    tipo: 'secundario', icono: Icons.description_outlined),
              ],
              const SizedBox(height: 10),
              BotonClaqueta('Abrir en Calendar', () =>
                  mostrarAviso(context, 'Simulado: se abre el evento en Google Calendar'),
                  tipo: 'secundario', icono: Icons.event_outlined),
              const SizedBox(height: 10),
              BotonClaqueta('Cancelar trabajo', () => _cancelar(context, t),
                  tipo: 'peligro', icono: Icons.delete_outline),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reprogramar(BuildContext context, Trabajo t, DateTime nueva) async {
    final ok = await confirmar(
      context,
      titulo: 'Reprogramar rodaje',
      mensaje: 'Mover "${t.titulo}" al ${fechaLarga(nueva)}?',
      boton: 'Reprogramar',
    );
    if (ok) {
      t.fecha = nueva;
      tienda.guardarTrabajo(t);
      if (context.mounted) mostrarAviso(context, 'Rodaje reprogramado para el ${fechaCorta(nueva)}');
    }
  }

  Future<void> _cancelar(BuildContext context, Trabajo t) async {
    final ok = await confirmar(
      context,
      titulo: '¿Cancelar el trabajo?',
      mensaje:
          '"${t.titulo}" sale de la agenda${t.enCalendar ? ' y se elimina el evento de Calendar' : ''}. No se puede deshacer.',
      boton: 'Cancelar trabajo',
      peligro: true,
    );
    if (ok && context.mounted) {
      tienda.eliminarTrabajo(t.id);
      Navigator.pop(context);
    }
  }

  Future<void> _registrarPago(BuildContext context, Trabajo t) async {
    String tipo = 'Anticipo 50%';
    String metodo = 'Transferencia';
    final monto = TextEditingController(text: (t.valor / 2).round().toString());
    const tipos = ['Anticipo 50%', 'Saldo', 'Otro monto'];
    const metodos = ['Transferencia', 'Efectivo', 'Otro'];

    final guardar = await hojaInferior<bool>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar pago', style: estiloDisplay(tamano: 16)),
            const SizedBox(height: 4),
            Text('Pendiente: ${formatearPesos(t.pendiente)}', style: estiloSuave(tamano: 13)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final x in tipos)
                  ChoiceChip(
                    label: Text(x),
                    selected: tipo == x,
                    selectedColor: Paleta.teal,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tipo == x ? Paleta.suelo : Paleta.tinta),
                    onSelected: (_) => setHoja(() {
                      tipo = x;
                      if (x == 'Anticipo 50%') monto.text = (t.valor / 2).round().toString();
                      if (x == 'Saldo') monto.text = t.pendiente.toString();
                      if (x == 'Otro monto') monto.text = '';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: monto,
              keyboardType: TextInputType.number,
              decoration: decoracionCampo('Monto (COP)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final x in metodos)
                  ChoiceChip(
                    label: Text(x),
                    selected: metodo == x,
                    selectedColor: Paleta.teal,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: metodo == x ? Paleta.suelo : Paleta.tinta),
                    onSelected: (_) => setHoja(() => metodo = x),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            BotonClaqueta('Guardar pago', () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );

    final valor = int.tryParse(monto.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (guardar != true || !context.mounted) return;
    if (valor <= 0) return mostrarAviso(context, 'Escribe un monto válido');
    if (valor > t.pendiente) {
      return mostrarAviso(context, 'El monto supera lo pendiente (${formatearPesos(t.pendiente)})');
    }
    tienda.registrarPago(
      t.id,
      Pago(tipo: tipo, monto: valor, metodo: metodo, fecha: DateTime.now()),
    );
    mostrarAviso(context, 'Pago registrado');
  }
}
