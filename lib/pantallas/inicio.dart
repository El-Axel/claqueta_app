import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'principal.dart';
import '../estilo.dart';
import 'ajustes.dart';
import 'catalogo.dart';
import 'nueva_cotizacion.dart';
import 'detalle_cotizacion.dart';
import 'agendar_trabajo.dart';
import 'detalle_trabajo.dart';
import '../servicios/nube.dart';

String _nombreCliente(int id) {
  for (final c in tienda.clientes) {
    if (c.id == id) return c.nombre;
  }
  return 'Un cliente';
}

/// Solicitud de un cliente: verla y convertirla en cotización (o descartarla).
Future<void> verSolicitud(BuildContext context, Map<String, dynamic> s) async {
  final clienteId = s['cliente_id'] as int;
  final fecha = s['fecha_tentativa'] == null ? null : DateTime.tryParse(s['fecha_tentativa'] as String);
  final accion = await hojaInferior<String>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solicitud de ${_nombreCliente(clienteId)}', style: estiloDisplay(tamano: 16)),
        const SizedBox(height: 12),
        Panel(
          child: Column(children: [
            FilaDato('Tipo', '${s['tipo']}'),
            if (fecha != null) FilaDato('Fecha tentativa', fechaLarga(fecha)),
            if ((s['lugar'] ?? '').toString().isNotEmpty) FilaDato('Lugar', '${s['lugar']}'),
          ]),
        ),
        if ((s['descripcion'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${s['descripcion']}', style: estiloSuave(tamano: 14)),
        ],
        const SizedBox(height: 16),
        BotonClaqueta('Crear cotización', () => Navigator.pop(ctx, 'cotizar'),
            icono: Icons.description_outlined),
        const SizedBox(height: 10),
        BotonClaqueta('Descartar', () => Navigator.pop(ctx, 'descartar'), tipo: 'secundario'),
      ],
    ),
  );
  if (accion == null || !context.mounted) return;
  try {
    if (accion == 'cotizar') {
      await servicioNube.marcarSolicitud(s['id'] as int, 'En cotización');
      if (context.mounted) ir(context, NuevaCotizacion(clienteId: clienteId));
    } else {
      await servicioNube.marcarSolicitud(s['id'] as int, 'Descartada');
    }
  } catch (_) {
    if (context.mounted) mostrarAviso(context, 'No se pudo actualizar la solicitud');
  }
}

/// El cliente pidió cambios en una cotización.
Future<void> verCambios(BuildContext context, Map<String, dynamic> r) async {
  final n = r['cot_n'] as int;
  final abrir = await hojaInferior<bool>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cambios pedidos en ${folio(n)}', style: estiloDisplay(tamano: 16)),
        const SizedBox(height: 10),
        Text('"${r['mensaje'] ?? ''}"', style: estiloSuave(tamano: 15)),
        const SizedBox(height: 16),
        BotonClaqueta('Abrir la cotización', () => Navigator.pop(ctx, true),
            icono: Icons.edit_note),
        const SizedBox(height: 10),
        BotonClaqueta('Marcar como visto', () => Navigator.pop(ctx, false), tipo: 'secundario'),
      ],
    ),
  );
  if (abrir == null || !context.mounted) return;
  await servicioNube.marcarCambioVisto(r['id'] as int).catchError((_) {});
  if (abrir && context.mounted && tienda.cotizacion(n) != null) {
    ir(context, DetalleCotizacion(n));
  }
}

class PestanaInicio extends StatelessWidget {
  const PestanaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tienda, servicioNube]),
      builder: (context, _) {
        final abiertas = tienda.cotizaciones
            .where((c) => c.estado == estBorrador || c.estado == estEnviada)
            .toList()
          ..sort((a, b) => b.n.compareTo(a.n));
        final proximos = tienda.proximos;
        final siguiente = proximos.isEmpty ? null : proximos.first;

        // ---- Alertas inteligentes ----
        final avisos = <Widget>[];
        // Lo que mandaron los clientes desde su espacio (va primero).
        for (final s in servicioNube.solicitudesNuevas) {
          avisos.add(Aviso(
            'Solicitud nueva de ${_nombreCliente(s['cliente_id'] as int)}: ${s['tipo']}. Toca para cotizarla.',
            icono: Icons.mark_email_unread_outlined,
            color: Paleta.arena,
            alTocar: () => verSolicitud(context, s),
          ));
        }
        for (final r in servicioNube.cambiosPedidos) {
          avisos.add(Aviso(
            '${_nombreCliente(r['cliente_id'] as int)} pidió cambios en ${folio(r['cot_n'] as int)}: '
            '"${r['mensaje'] ?? ''}"',
            icono: Icons.rate_review_outlined,
            color: Paleta.arena,
            alTocar: () => verCambios(context, r),
          ));
        }
        for (final c in tienda.porSeguimiento) {
          final dias = diasDesde(c.enviada!);
          avisos.add(Aviso(
            '${folio(c.n)} (${tienda.cliente(c.clienteId).nombre}) lleva $dias días sin respuesta. Toca para enviarle un recordatorio.',
            icono: Icons.notifications_active_outlined,
            color: Paleta.arena,
            alTocar: () => ir(context, DetalleCotizacion(c.n)),
          ));
        }
        final cruces = tienda.idsEnConflicto();
        if (cruces.isNotEmpty) {
          avisos.add(Aviso(
            'Tienes ${cruces.length} trabajos que se cruzan en la agenda. Revísalos para evitar choques.',
            icono: Icons.warning_amber_rounded,
            color: Paleta.terracota,
            alTocar: () => pestana.value = 2,
          ));
        }
        if (tienda.integracion('clima')) {
          for (final t in proximos) {
            final dias = soloFecha(t.fecha).difference(soloFecha(DateTime.now())).inDays;
            if (dias <= 3 && climaTrabajo(t).riesgoLluvia) {
              avisos.add(Aviso(
                'Lluvia ${climaTrabajo(t).lluvia}% el ${fechaCorta(t.fecha)} para "${t.titulo}". Mira el plan B.',
                icono: Icons.umbrella_outlined,
                alTocar: () => ir(context, DetalleTrabajo(t.id)),
              ));
            }
          }
        }

        final hoy = soloFecha(DateTime.now());
        int diasFalta = 0;
        if (siguiente != null) {
          diasFalta = soloFecha(siguiente.fecha).difference(hoy).inDays;
        }
        final facturable = tienda.cobrado + tienda.porCobrar;
        final double cobradoPct = facturable == 0 ? 0.0 : tienda.cobrado / facturable;

        final saludo = DateTime.now().hour < 12
            ? 'Buenos días'
            : (DateTime.now().hour < 19 ? 'Buenas tardes' : 'Buenas noches');
        final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
        final diasConTrabajo = <DateTime>{for (final t in proximos) soloFecha(t.fecha)};

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 124),
          children: [
            // ---- Cabecera: saludo y avatar ----
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(saludo,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
                      const SizedBox(height: 4),
                      Text('${nombreDia(hoy)} ${hoy.day} de ${mesesLargos[hoy.month - 1]}',
                          style: estiloSuave(tamano: 14)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ir(context, const PantallaAjustes()),
                  child: const Ficha('A', tamano: 46, redonda: true),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ---- Semana ----
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  _DiaSemana(
                    fecha: lunes.add(Duration(days: i)),
                    esHoy: lunes.add(Duration(days: i)) == hoy,
                    conTrabajo: diasConTrabajo.contains(lunes.add(Duration(days: i))),
                    alTocar: () => pestana.value = 2,
                  ),
              ],
            ),
            const SizedBox(height: 22),

            // ---- Próximo rodaje ----
            if (siguiente == null)
              TarjetaSuave(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Próximo rodaje'),
                    const SizedBox(height: 10),
                    const Text('Sin rodajes próximos',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Agenda un trabajo desde una cotización aceptada.',
                        style: estiloSuave(tamano: 14)),
                    const SizedBox(height: 18),
                    BotonArena('Agendar', () => ir(context, const PantallaAgendar())),
                  ],
                ),
              )
            else
              TarjetaSuave(
                alTocar: () => ir(context, DetalleTrabajo(siguiente.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const EtiquetaSeccion('Próximo rodaje'),
                        const Spacer(),
                        Text(
                          diasFalta <= 0
                              ? 'Hoy'
                              : (diasFalta == 1 ? 'Mañana' : 'En $diasFalta días'),
                          style: const TextStyle(
                              color: Paleta.arena, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(siguiente.titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.w700, height: 1.15)),
                              const SizedBox(height: 4),
                              Text(tienda.cliente(siguiente.clienteId).nombre,
                                  style: estiloSuave(tamano: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white.withAlpha(16)),
                          child: const Icon(Icons.arrow_outward, size: 18, color: Paleta.tinta),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DatoLinea(Icons.schedule,
                        '${fechaCorta(siguiente.fecha)} · ${hora12(siguiente.hora)}'),
                    const SizedBox(height: 8),
                    DatoLinea(Icons.place_outlined, siguiente.lugar),
                    if (tienda.integracion('clima')) ...[
                      const SizedBox(height: 8),
                      DatoLinea(climaTrabajo(siguiente).icono,
                          '${climaTrabajo(siguiente).temperatura}° ${climaTrabajo(siguiente).descripcion}'),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 30),

            // ---- Atajos ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Atajo(Icons.add, 'Cotizar', () => ir(context, const NuevaCotizacion()),
                    principal: true),
                Atajo(Icons.event_outlined, 'Agendar',
                    () => ir(context, const PantallaAgendar())),
                Atajo(Icons.inventory_2_outlined, 'Catálogo',
                    () => ir(context, const PantallaCatalogo())),
                Atajo(Icons.people_outline, 'Clientes', () => pestana.value = 4),
              ],
            ),
            const SizedBox(height: 34),

            // ---- Progreso de cobro: anillo central ----
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => pestana.value = 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      const EtiquetaSeccion('Progreso de cobro'),
                      const Spacer(),
                      Text('${mesAbreviado(hoy)} ${hoy.year}', style: estiloSuave(tamano: 13)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: CifraLado('Por cobrar', pesosCortos(tienda.porCobrar)),
                      ),
                      SizedBox(
                        width: 156,
                        height: 156,
                        child: CustomPaint(
                          painter: _PintorAnillo(cobradoPct),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(cobradoPct * 100).round()}%',
                                    style: estiloDisplay(tamano: 30)),
                                const SizedBox(height: 4),
                                Text('cobrado', style: estiloSuave(tamano: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CifraLado('Cobrado', pesosCortos(tienda.cobrado)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (avisos.isNotEmpty) ...[
              const SizedBox(height: 10),
              const TituloSeccion('Requiere tu atención'),
              ...avisos,
            ],
            const SizedBox(height: 6),
            TituloSeccion('Pendientes', accion: 'Ver todo', alAccion: () => pestana.value = 1),
            if (abiertas.isEmpty)
              const Vacio('Todo al día', 'No hay cotizaciones abiertas.')
            else
              for (final c in abiertas)
                FilaCot(c, alTocar: () => ir(context, DetalleCotizacion(c.n))),
          ],
        );
      },
    );
  }
}

// ======================================================================
// Piezas propias del Home. TarjetaSuave, EtiquetaSeccion, DatoLinea,
// Atajo, CifraLado y BotonArena ahora son públicas (estilo.dart) para
// que el resto de pantallas use exactamente el mismo diseño.
// ======================================================================

class _DiaSemana extends StatelessWidget {
  final DateTime fecha;
  final bool esHoy;
  final bool conTrabajo;
  final VoidCallback alTocar;
  const _DiaSemana(
      {required this.fecha,
      required this.esHoy,
      required this.conTrabajo,
      required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: esHoy ? Colors.white.withAlpha(18) : Colors.transparent,
            border: Border.all(color: esHoy ? Colors.white.withAlpha(40) : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(nombreDia(fecha),
                  style: TextStyle(
                      fontSize: 12,
                      color: Paleta.tinta.withAlpha(esHoy ? 200 : 120))),
              const SizedBox(height: 8),
              Text('${fecha.day}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: esHoy ? Paleta.tinta : Paleta.tinta.withAlpha(150))),
              const SizedBox(height: 7),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: conTrabajo ? Paleta.arena : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double valor;
  _PintorAnillo(this.valor);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.width / 2 - 6;
    final pista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Paleta.tinta.withAlpha(26);
    canvas.drawCircle(centro, radio, pista);
    final v = valor.clamp(0.0, 1.0).toDouble();
    if (v > 0) {
      final arco = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Paleta.arena;
      canvas.drawArc(Rect.fromCircle(center: centro, radius: radio), -math.pi / 2,
          2 * math.pi * v, false, arco);
    }
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) => anterior.valor != valor;
}
