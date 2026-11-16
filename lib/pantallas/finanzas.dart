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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Finanzas', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text('Cómo va tu negocio', style: estiloSuave(tamano: 13)),
            const SizedBox(height: 18),

            // ---- Tarjeta hero con la cifra grande y tres cuadros oscuros ----
            TarjetaHero(
              relleno: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PildoraOscura('COP'),
                      const SizedBox(width: 8),
                      PildoraOscura('${(cobradoPct * 100).round()}% cobrado'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Cobrado',
                      style: TextStyle(
                          color: Paleta.suelo.withAlpha(180),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatearPesos(tienda.cobrado),
                        style: estiloDisplay(tamano: 38, color: Paleta.suelo)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _CuadroOscuro('Por cobrar', pesosCortos(tienda.porCobrar)),
                      const SizedBox(width: 8),
                      _CuadroOscuro('Aceptado', pesosCortos(tienda.aceptado)),
                      const SizedBox(width: 8),
                      _CuadroOscuro('Negociación', pesosCortos(tienda.enNegociacion)),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Cápsulas por mes (referente "Great Progress") ----
            const TituloSeccion('Cobrado por mes'),
            Panel(
              relleno: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                                  const Text('Últimos 6 meses',
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('Lo que ya entró a tu bolsillo',
                                      style: estiloSuave(tamano: 12)),
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
                  const Divider(color: Colors.white24, height: 26),
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

class _CuadroOscuro extends StatelessWidget {
  final String titulo;
  final String valor;
  const _CuadroOscuro(this.titulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Paleta.suelo.withAlpha(200),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(valor, style: estiloDisplay(tamano: 15)),
            ),
            const SizedBox(height: 4),
            Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: estiloSuave(tamano: 11)),
          ],
        ),
      ),
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
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          child: Container(
            height: relleno,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: destacada
                    ? [const Color(0xFFD9A94E), Paleta.arena, const Color(0xFFF8DA9C)]
                    : [const Color(0xFF14403B), Paleta.teal.withAlpha(150)],
              ),
              boxShadow: destacada
                  ? [BoxShadow(color: Paleta.arena.withAlpha(70), blurRadius: 14)]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(mes, style: estiloSuave(tamano: 11)),
      ],
    );
  }
}
