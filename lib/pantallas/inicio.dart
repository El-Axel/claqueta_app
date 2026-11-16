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

class PestanaInicio extends StatelessWidget {
  const PestanaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final abiertas = tienda.cotizaciones
            .where((c) => c.estado == estBorrador || c.estado == estEnviada)
            .toList()
          ..sort((a, b) => b.n.compareTo(a.n));
        final proximos = tienda.proximos;
        final siguiente = proximos.isEmpty ? null : proximos.first;

        // ---- Alertas inteligentes ----
        final avisos = <Widget>[];
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
            if (dias <= 3 && climaDe(t.fecha).riesgoLluvia) {
              avisos.add(Aviso(
                'Lluvia ${climaDe(t.fecha).lluvia}% el ${fechaCorta(t.fecha)} para "${t.titulo}". Mira el plan B.',
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          children: [
            // ---- Cabecera: círculo, píldora de resumen, ajustes y avatar ----
            Row(
              children: [
                BotonCirculo(Icons.inventory_2_outlined,
                    () => ir(context, const PantallaCatalogo())),
                const SizedBox(width: 8),
                Flexible(
                  child: PildoraOscura(
                    '${abiertas.length} cotizaciones abiertas',
                    icono: Icons.description_outlined,
                    sobreHero: false,
                  ),
                ),
                const Spacer(),
                BotonCirculo(Icons.settings_outlined, () => ir(context, const PantallaAjustes())),
                const SizedBox(width: 8),
                const Ficha('A', tamano: 42, redonda: true),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              '${nombreDia(hoy)} ${hoy.day} ${mesesLargos[hoy.month - 1]} ${hoy.year}',
              style: estiloSuave(tamano: 13),
            ),
            const SizedBox(height: 8),
            Text('Cotiza, agenda', style: estiloDisplay(tamano: 28)),
            Text('y cobra hoy', style: estiloDisplay(tamano: 28, color: Paleta.arena)),
            const SizedBox(height: 20),

            // ---- Tarjeta hero: el próximo rodaje ----
            if (siguiente == null)
              TarjetaHero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin rodajes próximos',
                        style: estiloDisplay(tamano: 18, color: Paleta.suelo)),
                    const SizedBox(height: 6),
                    Text('Agenda un trabajo desde una cotización aceptada.',
                        style: TextStyle(color: Paleta.suelo.withAlpha(190), fontSize: 13)),
                    const SizedBox(height: 18),
                    BotonPildora('Agendar', () => ir(context, const PantallaAgendar()),
                        icono: Icons.event_outlined),
                  ],
                ),
              )
            else
              TarjetaHero(
                alTocar: () => ir(context, DetalleTrabajo(siguiente.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRÓXIMO RODAJE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                      color: Paleta.suelo.withAlpha(170))),
                              const SizedBox(height: 8),
                              Text(siguiente.titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: estiloDisplay(tamano: 17, color: Paleta.suelo)),
                              const SizedBox(height: 4),
                              Text(tienda.cliente(siguiente.clienteId).nombre,
                                  style: TextStyle(
                                      color: Paleta.suelo.withAlpha(190), fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            Text(diasFalta <= 0 ? 'HOY' : '$diasFalta',
                                style: estiloDisplay(
                                    tamano: diasFalta <= 0 ? 26 : 46, color: Paleta.suelo)),
                            if (diasFalta > 0)
                              Text(diasFalta == 1 ? 'día' : 'días',
                                  style: TextStyle(
                                      color: Paleta.suelo.withAlpha(190),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PildoraOscura('${fechaCorta(siguiente.fecha)} · ${hora12(siguiente.hora)}',
                            icono: Icons.schedule),
                        PildoraOscura(siguiente.lugar, icono: Icons.place_outlined),
                        if (tienda.integracion('clima'))
                          PildoraOscura(
                            '${climaDe(siguiente.fecha).temperatura}° ${climaDe(siguiente.fecha).descripcion}',
                            icono: climaDe(siguiente.fecha).icono,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    BotonPildora('Ver rodaje', () => ir(context, DetalleTrabajo(siguiente.id)),
                        icono: Icons.arrow_outward),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ---- Acciones rápidas ----
            Row(
              children: [
                AccionRapida(Icons.add_circle_outline, 'Cotizar',
                    () => ir(context, const NuevaCotizacion()),
                    resaltada: true),
                AccionRapida(Icons.event_outlined, 'Agendar',
                    () => ir(context, const PantallaAgendar())),
                AccionRapida(Icons.inventory_2_outlined, 'Catálogo',
                    () => ir(context, const PantallaCatalogo())),
                AccionRapida(Icons.people_outline, 'Clientes', () => pestana.value = 4),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Progreso de cobro (referente "Today's Progress") ----
            Panel(
              relleno: const EdgeInsets.all(18),
              alTocar: () => pestana.value = 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Progreso de cobro',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      PildoraOscura('${mesAbreviado(hoy)} ${hoy.year}', sobreHero: false),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '${pesosCortos(tienda.cobrado)} de ${pesosCortos(facturable)}',
                          style: estiloSuave(tamano: 13),
                        ),
                      ),
                      Text('${(cobradoPct * 100).round()}%',
                          style: estiloDisplay(tamano: 22)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BarraBrillante(cobradoPct),
                ],
              ),
            ),
            if (avisos.isNotEmpty) ...[
              const TituloSeccion('Requiere tu atención'),
              ...avisos,
            ],
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
