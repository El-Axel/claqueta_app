import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../modelos.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../util.dart';
import '../../widgets.dart';
import 'cotizaciones_cliente.dart';
import 'piezas_cliente.dart';

// ---------------------------------------------------------------
// DETALLE DEL RODAJE (vista del cliente): cuándo, dónde, qué clima se
// espera y cómo van sus pagos. Solo lectura: los pagos los registra el
// realizador.
// ---------------------------------------------------------------

class DetalleRodajeCliente extends StatelessWidget {
  final int id;
  const DetalleRodajeCliente(this.id, {super.key});

  Trabajo? get _trabajo {
    for (final t in portal.trabajos) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra('Rodaje'),
      body: ListenableBuilder(
        listenable: portal,
        builder: (context, _) {
          final t = _trabajo;
          if (t == null) {
            return Pagina([
              const EstadoPortal(),
              const Vacio('Rodaje no disponible', 'Puede que tu realizador lo haya cambiado.'),
            ]);
          }
          final coord = coordenadasTrabajo(t);
          final avance = t.valor == 0 ? 1.0 : t.pagado / t.valor;
          final pagos = [...t.pagos]..sort((a, b) => b.fecha.compareTo(a.fecha));
          return Pagina([
            const EstadoPortal(),
            Text(t.titulo, style: estiloTituloPantalla()),
            const SizedBox(height: 8),
            DatoLinea(Icons.schedule, '${fechaLarga(t.fecha)} · ${hora12(t.hora)}'),
            const SizedBox(height: 6),
            DatoLinea(Icons.place_outlined, t.zona.isEmpty ? t.lugar : '${t.lugar} · ${t.zona}'),
            const SizedBox(height: 18),
            MapaLugar(t.lugar, zona: t.zona, lat: coord?.$1, lon: coord?.$2),
            const SizedBox(height: 12),
            TarjetaClima(t.fecha, lat: coord?.$1, lon: coord?.$2),
            const SizedBox(height: 12),

            // ---- Pagos ----
            TarjetaSuave(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const EtiquetaSeccion('Pagos'),
                      const Spacer(),
                      if (t.pendiente == 0)
                        const Etiqueta('Pagado', color: Paleta.teal)
                      else
                        Text('${(avance * 100).round()}%',
                            style: const TextStyle(
                                color: Paleta.arena, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: CifraLado('Pagado', formatearPesos(t.pagado))),
                      Container(width: 1, height: 36, color: Colors.white.withAlpha(20)),
                      Expanded(
                        child: CifraLado('Pendiente', formatearPesos(t.pendiente),
                            color: t.pendiente > 0 ? Paleta.arena : Paleta.tinta),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BarraProgreso(avance),
                  const SizedBox(height: 8),
                  Text('Valor total ${formatearPesos(t.valor)}', style: estiloSuave(tamano: 12.5)),
                  if (pagos.isNotEmpty) ...[
                    Divider(height: 26, color: Colors.white.withAlpha(20)),
                    for (final p in pagos) _FilaPago(p),
                  ],
                ],
              ),
            ),
            if (t.cotN != null) ...[
              const SizedBox(height: 12),
              Panel(
                alTocar: () => ir(context, DetalleCotizacionCliente(t.cotN!)),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: Paleta.tinta.withAlpha(170)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Ver cotización ${folio(t.cotN!)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Icon(Icons.chevron_right, color: Paleta.tinta.withAlpha(120)),
                  ],
                ),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

/// Renglón de un pago: tipo (anticipo, saldo...), método, fecha y monto.
class _FilaPago extends StatelessWidget {
  final Pago p;
  const _FilaPago(this.p);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Paleta.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.tipo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${p.metodo} · ${fechaCorta(p.fecha)}', style: estiloSuave(tamano: 12)),
              ],
            ),
          ),
          Text(formatearPesos(p.monto),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
