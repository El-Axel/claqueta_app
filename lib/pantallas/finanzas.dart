import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_trabajo.dart';
import 'detalle_cliente.dart';
import '../estilo.dart';

// Tablero de finanzas: todo se calcula a partir de las cotizaciones y los
// pagos registrados. No hay datos "aparte": si registras un pago, cambia aquí.
class PestanaFinanzas extends StatelessWidget {
  const PestanaFinanzas({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final meses = tienda.cobradoPorMes(6);
        int maximo = 0;
        for (final m in meses) {
          if (m.valor > maximo) maximo = m.valor;
        }
        final pendientes = tienda.trabajos.where((t) => t.pendiente > 0).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        final top = tienda.topClientes;
        final facturable = tienda.cobrado + tienda.porCobrar;
        final double cobradoPct = facturable == 0 ? 0.0 : tienda.cobrado / facturable;
        int destacado = 0;
        for (int k = 0; k < meses.length; k++) {
          if (meses[k].valor > meses[destacado].valor) destacado = k;
        }
        int total6 = 0;
        for (final m in meses) {
          total6 += m.valor;
        }

        return ListView(
          // Mismos márgenes que el Home.
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 124),
          children: [
            const Encabezado('Finanzas', subtitulo: 'Cómo va tu negocio'),
            const SizedBox(height: 22),

            // ---- Resumen en tarjeta suave (antes degradado teal -> arena) ----
            // Misma receta del Home: etiqueta pequeña, cifra grande y, abajo,
            // tres cifras con su nombre (CifraLado).
            TarjetaSuave(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expanded (no Spacer): la etiqueta cede espacio y no desborda
                  // en pantallas angostas.
                  Row(
                    children: [
                      const Expanded(child: EtiquetaSeccion('Cobrado · COP')),
                      const SizedBox(width: 8),
                      Text('${(cobradoPct * 100).round()}% cobrado',
                          style: const TextStyle(
                              color: Paleta.arena, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatearPesos(tienda.cobrado), style: estiloDisplay(tamano: 32)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: CifraLado('Por cobrar', pesosCortos(tienda.porCobrar))),
                      Expanded(child: CifraLado('Aceptado', pesosCortos(tienda.aceptado))),
                      Expanded(
                          child: CifraLado('Negociación', pesosCortos(tienda.enNegociacion))),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Cápsulas por mes (referente "Great Progress") ----
            const TituloSeccion('Cobrado por mes'),
            TarjetaSuave(
              relleno: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: maximo == 0
                  ? Text('Aún no hay pagos registrados.', style: estiloSuave(tamano: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const EtiquetaSeccion('Últimos 6 meses'),
                                  const SizedBox(height: 6),
                                  Text('Lo que ya entró a tu bolsillo',
                                      style: estiloSuave(tamano: 13)),
                                ],
                              ),
                            ),
                            Text(pesosCortos(total6), style: estiloDisplay(tamano: 22)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 190,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (int k = 0; k < meses.length; k++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: _Capsula(
                                      valor: meses[k].valor,
                                      maximo: maximo,
                                      mes: mesAbreviado(meses[k].mes),
                                      destacada: k == destacado,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const TituloSeccion('Cotizaciones'),
            Panel(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${tienda.tasaAceptacion}%',
                          style: estiloDisplay(tamano: 54, color: Paleta.arena)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('de las cotizaciones respondidas fueron aceptadas',
                              style: estiloSuave(tamano: 12)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  for (final e in estados)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Etiqueta(e, color: coloresEstado[e] ?? Paleta.teal),
                          const Spacer(),
                          Text('${tienda.contarEstado(e)}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const TituloSeccion('Por cobrar'),
            if (pendientes.isEmpty)
              const Vacio('Sin saldos pendientes', 'Todos tus trabajos están pagados.')
            else
              for (final t in pendientes)
                FilaItem(
                  titulo: t.titulo,
                  subtitulo: '${tienda.cliente(t.clienteId).nombre} · ${fechaCorta(t.fecha)}',
                  derecha: formatearPesos(t.pendiente),
                  derecha2: 'de ${pesosCortos(t.valor)}',
                  alTocar: () => ir(context, DetalleTrabajo(t.id)),
                ),
            const TituloSeccion('Mejores clientes'),
            if (top.isEmpty)
              const Vacio('Aún sin datos', 'Aparecerán cuando acepten cotizaciones.')
            else
              for (final e in top)
                FilaItem(
                  titulo: e.key.nombre,
                  subtitulo: 'Cotizaciones aceptadas',
                  derecha: formatearPesos(e.value),
                  alTocar: () => ir(context, DetalleCliente(e.key.id)),
                ),
          ],
        );
      },
    );
  }
}

/// Cápsula vertical: riel oscuro con el relleno por dentro. La destacada
/// brilla en arena y muestra su valor en una burbuja.
class _Capsula extends StatelessWidget {
  final int valor;
  final int maximo;
  final String mes;
  final bool destacada;

  const _Capsula({
    required this.valor,
    required this.maximo,
    required this.mes,
    required this.destacada,
  });

  @override
  Widget build(BuildContext context) {
    const alto = 130.0;
    final relleno = valor == 0 ? 0.0 : (alto * valor / maximo).clamp(18.0, alto).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 28,
          child: destacada && valor > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Paleta.arena,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pesosCortos(valor),
                      maxLines: 1,
                      style: const TextStyle(
                          color: Paleta.suelo, fontSize: 10, fontWeight: FontWeight.w800)),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Container(
          height: alto,
          alignment: Alignment.bottomCenter,
          // Riel casi invisible; relleno plano (sin degradado ni brillo).
          // Solo el mes destacado lleva el acento arena; los demás, tinta
          // tenue, igual que la pista del anillo de cobro del Home.
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            height: relleno,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: destacada ? Paleta.arena : Paleta.tinta.withAlpha(40),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(mes, style: estiloSuave(tamano: 11)),
      ],
    );
  }
}
