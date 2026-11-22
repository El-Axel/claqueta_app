import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../modelos.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../util.dart';
import '../../widgets.dart';
import '../entrada.dart';

// ---------------------------------------------------------------
// PIEZAS DEL ESPACIO DEL CLIENTE: ayudas que comparten las pestañas
// del portal (fechas relativas, estado de carga, salir...). Viven aquí
// y no en widgets.dart para no tocar los archivos del realizador.
// ---------------------------------------------------------------

/// Pestaña activa del portal. Global (como `pestana` del realizador)
/// para que cualquier pantalla del cliente pueda saltar a otra.
final ValueNotifier<int> pestanaCliente = ValueNotifier<int>(0);

/// Cuántas novedades estaban sin leer al abrir la pestaña Novedades.
/// Se guarda ANTES de marcarlas como vistas para poder resaltarlas
/// en esa visita (si no, el resalte desaparecería al instante).
final ValueNotifier<int> novedadesResaltadas = ValueNotifier<int>(0);

/// Las fechas de Supabase llegan como texto ISO en UTC: se pasan a la
/// hora del teléfono para que "hoy" y "ayer" sean los del cliente.
DateTime? fechaDeTexto(dynamic valor) {
  if (valor is! String) return null;
  return DateTime.tryParse(valor)?.toLocal();
}

/// "hoy, 3:05 pm", "ayer", "hace 3 días" o la fecha corta si es vieja.
String fechaRelativa(DateTime f, {DateTime? ahora}) {
  final hoy = soloFecha(ahora ?? DateTime.now());
  final dias = hoy.difference(soloFecha(f)).inDays;
  if (dias <= 0) {
    return 'hoy, ${hora12('${f.hour}:${f.minute.toString().padLeft(2, '0')}')}';
  }
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';
  return fechaCorta(f);
}

/// Color de la etiqueta de una solicitud según su estado.
Color colorSolicitud(String estado) {
  switch (estado) {
    case 'En cotización':
      return Paleta.teal;
    case 'Descartada':
      return Paleta.terracota;
    default:
      return Paleta.arena; // Nueva
  }
}

/// Color del estado de una cotización (el mismo del realizador).
Color colorCotizacion(String estado) => coloresEstado[estado] ?? Paleta.tinta;

/// Rodajes de hoy en adelante, del más cercano al más lejano.
List<Trabajo> rodajesProximos() {
  final hoy = soloFecha(DateTime.now());
  return portal.trabajos.where((t) => !soloFecha(t.fecha).isBefore(hoy)).toList()
    ..sort((a, b) {
      final f = soloFecha(a.fecha).compareTo(soloFecha(b.fecha));
      return f != 0 ? f : minutos(a.hora).compareTo(minutos(b.hora));
    });
}

/// Rodajes que ya pasaron, del más reciente al más viejo.
List<Trabajo> rodajesPasados() {
  final hoy = soloFecha(DateTime.now());
  return portal.trabajos.where((t) => soloFecha(t.fecha).isBefore(hoy)).toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
}

/// Cotizaciones que esperan que el cliente decida (enviadas y sin
/// una respuesta suya todavía sin procesar).
List<Cotizacion> cotizacionesPorResponder() => portal.cotizaciones
    .where((c) => c.estado == estEnviada && portal.respuestaPendiente(c.n) == null)
    .toList();

/// Nombre del realizador para los textos ("esperando a Estudio X").
String nombreRealizador() => portal.negocio.trim().isEmpty ? 'tu realizador' : portal.negocio;

/// Pregunta y sale del modo cliente: vuelve a la pantalla de entrada
/// borrando la pila (para que "atrás" no regrese al portal).
Future<void> salirDelPortal(BuildContext context) async {
  final ok = await confirmar(
    context,
    titulo: 'Salir de tu espacio',
    mensaje: 'Para volver a entrar necesitarás de nuevo tu código de invitación.',
    boton: 'Salir',
    peligro: true,
  );
  if (!ok || !context.mounted) return;
  await portal.salir();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const PantallaEntrada()),
    (r) => false,
  );
}

/// Título grande de pestaña (igual al saludo del Home) con subtítulo.
class CabeceraCliente extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? derecha;
  const CabeceraCliente(this.titulo, {super.key, this.subtitulo, this.derecha});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: estiloTituloPantalla()),
                if (subtitulo != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitulo!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: estiloSuave(tamano: 14)),
                ],
              ],
            ),
          ),
          if (derecha != null) ...[const SizedBox(width: 12), derecha!],
        ],
      ),
    );
  }
}

/// Franja de estado del portal: barra fina mientras actualiza y aviso
/// tocable si falló (reintenta). Si todo va bien no ocupa espacio.
class EstadoPortal extends StatelessWidget {
  const EstadoPortal({super.key});

  @override
  Widget build(BuildContext context) {
    if (portal.error != null) {
      return Aviso(
        '${portal.error} Toca para reintentar.',
        icono: Icons.wifi_off_rounded,
        color: Paleta.terracota,
        alTocar: () => portal.cargar(),
      );
    }
    if (portal.cargando) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.white.withAlpha(18),
            valueColor: const AlwaysStoppedAnimation<Color>(Paleta.arena),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Indicador centrado para la primera carga (cuando aún no hay datos).
class CargandoPortal extends StatelessWidget {
  final String texto;
  const CargandoPortal({super.key, this.texto = 'Cargando tu espacio…'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Paleta.arena),
          ),
          const SizedBox(height: 14),
          Text(texto, style: estiloSuave(tamano: 13)),
        ],
      ),
    );
  }
}

/// Lista con "jalar para actualizar". La física siempre desplazable
/// hace que el gesto funcione aunque la lista sea corta o esté vacía.
class ListaPortal extends StatelessWidget {
  final List<Widget> hijos;
  const ListaPortal(this.hijos, {super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Paleta.suelo,
      backgroundColor: Paleta.arena,
      onRefresh: () => portal.cargar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Abajo deja sitio para el dock flotante (igual que el Home).
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 124),
        children: hijos,
      ),
    );
  }
}

/// Fila de un rodaje del cliente (fecha, hora y lugar).
class FilaRodajeCliente extends StatelessWidget {
  final Trabajo t;
  final VoidCallback alTocar;
  const FilaRodajeCliente(this.t, {super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) => FilaItem(
        titulo: t.titulo,
        subtitulo: '${fechaCorta(t.fecha)} · ${hora12(t.hora)} · ${t.lugar}',
        derecha: pesosCortos(t.valor),
        extra: t.pendiente == 0
            ? const Etiqueta('Pagado', color: Paleta.teal)
            : null,
        alTocar: alTocar,
      );
}

/// Fila de una cotización del cliente (proyecto, folio, total y estado).
class FilaCotCliente extends StatelessWidget {
  final Cotizacion c;
  final VoidCallback alTocar;
  const FilaCotCliente(this.c, {super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final pendiente = portal.respuestaPendiente(c.n) != null;
    return FilaItem(
      titulo: c.proyecto,
      subtitulo: '${folio(c.n)} · ${fechaCorta(c.enviada ?? c.creada)}',
      derecha: formatearPesos(c.total),
      extra: pendiente && c.estado == estEnviada
          ? const Etiqueta('Respondida', color: Paleta.arena)
          : Etiqueta(c.estado, color: colorCotizacion(c.estado)),
      alTocar: alTocar,
    );
  }
}
