import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../modelos.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../util.dart';
import '../../widgets.dart';
import 'cotizaciones_cliente.dart';
import 'piezas_cliente.dart';
import 'rodaje_cliente.dart';

// ---------------------------------------------------------------
// INICIO DEL CLIENTE: lo más importante de un vistazo, con el mismo
// orden del Home del realizador: quién eres, el próximo rodaje, lo que
// espera tu respuesta y cómo van los pagos.
// ---------------------------------------------------------------

class PestanaInicioCliente extends StatelessWidget {
  const PestanaInicioCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: portal,
      builder: (context, _) {
        final proximos = rodajesProximos();
        final siguiente = proximos.isEmpty ? null : proximos.first;
        final porResponder = cotizacionesPorResponder();
        final pagado = portal.trabajos.fold<int>(0, (a, t) => a + t.pagado);
        final pendiente = portal.trabajos.fold<int>(0, (a, t) => a + t.pendiente);
        final total = pagado + pendiente;
        final sinDatos = portal.cotizaciones.isEmpty && portal.trabajos.isEmpty;
        final nombre = portal.nombreCliente.trim().split(' ').first;

        return ListaPortal([
          // ---- Cabecera: saludo y salir ----
          CabeceraCliente(
            nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
            subtitulo: 'Tu realizador: ${nombreRealizador()}',
            derecha: Tooltip(
              message: 'Salir',
              child: BotonCirculo(Icons.logout_rounded, () => salirDelPortal(context),
                  tamano: 42),
            ),
          ),
          const EstadoPortal(),
          if (portal.cargando && sinDatos)
            const CargandoPortal()
          else ...[
            if (portal.noLeidas > 0)
              Aviso(
                portal.noLeidas == 1
                    ? 'Tienes 1 novedad de ${nombreRealizador()}.'
                    : 'Tienes ${portal.noLeidas} novedades de ${nombreRealizador()}.',
                icono: Icons.notifications_active_outlined,
                color: Paleta.arena,
                alTocar: () {
                  novedadesResaltadas.value = portal.noLeidas;
                  portal.marcarNovedadesVistas();
                  pestanaCliente.value = 3;
                },
              ),

            // ---- Próximo rodaje ----
            if (siguiente == null)
              TarjetaSuave(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Próximo rodaje'),
                    const SizedBox(height: 10),
                    const Text('Sin rodajes agendados',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'Cuando aceptes una cotización, ${nombreRealizador()} agendará el rodaje y lo verás aquí.',
                      style: estiloSuave(tamano: 14),
                    ),
                    const SizedBox(height: 18),
                    BotonArena('Pedir una cotización', () => pestanaCliente.value = 2),
                  ],
                ),
              )
            else
              _TarjetaProximo(siguiente),
            const SizedBox(height: 10),

            // ---- Requiere tu respuesta ----
            if (porResponder.isNotEmpty) ...[
              const TituloSeccion('Requiere tu respuesta'),
              for (final c in porResponder)
                FilaCotCliente(c,
                    alTocar: () => ir(context, DetalleCotizacionCliente(c.n))),
            ],

            // ---- Pagos ----
            if (total > 0) ...[
              const SizedBox(height: 6),
              TarjetaSuave(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const EtiquetaSeccion('Tus pagos'),
                        const Spacer(),
                        Text('${(pagado * 100 / total).round()}% pagado',
                            style: const TextStyle(
                                color: Paleta.arena,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: CifraLado('Pagado', formatearPesos(pagado))),
                        Container(width: 1, height: 36, color: Colors.white.withAlpha(20)),
                        Expanded(
                          child: CifraLado('Pendiente', formatearPesos(pendiente),
                              color: pendiente > 0 ? Paleta.arena : Paleta.tinta),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BarraProgreso(pagado / total),
                  ],
                ),
              ),
            ],

            // ---- Historial ----
            const SizedBox(height: 10),
            TituloSeccion('Historial',
                accion: 'Ver todo', alAccion: () => ir(context, const PantallaHistorialCliente())),
            Panel(
              alTocar: () => ir(context, const PantallaHistorialCliente()),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: Paleta.tinta.withAlpha(170)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _resumenHistorial(),
                      style: TextStyle(fontSize: 14, color: Paleta.tinta.withAlpha(215)),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Paleta.tinta.withAlpha(120)),
                ],
              ),
            ),
          ],
        ]);
      },
    );
  }

  String _resumenHistorial() {
    final rodajes = rodajesPasados().length;
    final cerradas = portal.cotizaciones
        .where((c) => c.estado == estAceptada || c.estado == estRechazada)
        .length;
    if (rodajes == 0 && cerradas == 0) return 'Aún no hay rodajes pasados ni cotizaciones cerradas.';
    String plural(int n, String uno, String varios) => n == 1 ? '1 $uno' : '$n $varios';
    return '${plural(rodajes, 'rodaje pasado', 'rodajes pasados')} · '
        '${plural(cerradas, 'cotización cerrada', 'cotizaciones cerradas')}';
  }
}

/// Tarjeta del próximo rodaje (mismo diseño que la del Home).
class _TarjetaProximo extends StatelessWidget {
  final Trabajo t;
  const _TarjetaProximo(this.t);

  @override
  Widget build(BuildContext context) {
    final dias = soloFecha(t.fecha).difference(soloFecha(DateTime.now())).inDays;
    final clima = climaTrabajo(t);
    return TarjetaSuave(
      alTocar: () => ir(context, DetalleRodajeCliente(t.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EtiquetaSeccion('Próximo rodaje'),
              const Spacer(),
              Text(
                dias <= 0 ? 'Hoy' : (dias == 1 ? 'Mañana' : 'En $dias días'),
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
                child: Text(t.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, height: 1.15)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(16)),
                child: const Icon(Icons.arrow_outward, size: 18, color: Paleta.tinta),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DatoLinea(Icons.schedule, '${fechaCorta(t.fecha)} · ${hora12(t.hora)}'),
          const SizedBox(height: 8),
          DatoLinea(Icons.place_outlined, t.zona.isEmpty ? t.lugar : '${t.lugar} · ${t.zona}'),
          const SizedBox(height: 8),
          DatoLinea(clima.icono, '${clima.temperatura}° ${clima.descripcion}'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// HISTORIAL: rodajes que ya pasaron y cotizaciones cerradas
// (aceptadas o rechazadas). Solo lectura.
// ---------------------------------------------------------------
class PantallaHistorialCliente extends StatelessWidget {
  const PantallaHistorialCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra('Historial'),
      body: ListenableBuilder(
        listenable: portal,
        builder: (context, _) {
          final pasados = rodajesPasados();
          final cerradas = portal.cotizaciones
              .where((c) => c.estado == estAceptada || c.estado == estRechazada)
              .toList()
            ..sort((a, b) => b.n.compareTo(a.n));
          return RefreshIndicator(
            color: Paleta.suelo,
            backgroundColor: Paleta.arena,
            onRefresh: () => portal.cargar(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              children: [
                const EstadoPortal(),
                const TituloSeccion('Rodajes pasados'),
                if (pasados.isEmpty)
                  const Vacio('Sin rodajes pasados', 'Aquí quedarán los rodajes ya realizados.')
                else
                  for (final t in pasados)
                    FilaRodajeCliente(t, alTocar: () => ir(context, DetalleRodajeCliente(t.id))),
                const SizedBox(height: 8),
                const TituloSeccion('Cotizaciones cerradas'),
                if (cerradas.isEmpty)
                  const Vacio('Nada por aquí',
                      'Las cotizaciones que aceptes o rechaces aparecerán aquí.')
                else
                  for (final c in cerradas)
                    FilaCotCliente(c,
                        alTocar: () => ir(context, DetalleCotizacionCliente(c.n))),
              ],
            ),
          );
        },
      ),
    );
  }
}
