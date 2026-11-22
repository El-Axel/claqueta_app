import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'nueva_cotizacion.dart';
import 'detalle_cotizacion.dart';
import 'catalogo.dart';
import '../estilo.dart';

// Lista de cotizaciones con búsqueda y filtro por estado.
// Es StatefulWidget porque recuerda el filtro y el texto buscado.
class PestanaCotizar extends StatefulWidget {
  const PestanaCotizar({super.key});

  @override
  State<PestanaCotizar> createState() => _PestanaCotizarState();
}

class _PestanaCotizarState extends State<PestanaCotizar> {
  String filtro = 'Todas';
  String busqueda = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final q = busqueda.toLowerCase();
        final lista = tienda.cotizaciones.where((c) {
          if (filtro != 'Todas' && c.estado != filtro) return false;
          if (q.isEmpty) return true;
          final texto = '${folio(c.n)} ${tienda.cliente(c.clienteId).nombre} ${c.proyecto}'.toLowerCase();
          return texto.contains(q);
        }).toList()
          ..sort((a, b) => b.n.compareTo(a.n));

        final filtros = ['Todas', ...estados];

        return ListView(
          // Mismos márgenes que el Home (22 a los lados, 14 arriba).
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 124),
          children: [
            const Encabezado('Cotizaciones', subtitulo: 'Crea, envía y da seguimiento'),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: BotonClaqueta('Nueva cotización',
                      () => ir(context, const NuevaCotizacion()), icono: Icons.add),
                ),
                const SizedBox(width: 10),
                BotonCirculo(Icons.inventory_2_outlined,
                    () => ir(context, const PantallaCatalogo()),
                    tamano: 54),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => busqueda = v),
              decoration: decoracionCampo('Buscar cliente o proyecto',
                  icono: const Icon(Icons.search, size: 20)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in filtros)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => filtro = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          // Chip limpio: arena si está elegido, vidrio suave si no.
                          // Sin sombra teal (el estilo limpio usa un solo acento).
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: filtro == f ? Paleta.arena : Colors.white.withAlpha(13),
                            border: Border.all(
                              color: filtro == f ? Colors.transparent : Colors.white.withAlpha(22),
                            ),
                          ),
                          child: Text(
                            f == 'Todas' ? f : '$f ${tienda.contarEstado(f)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: filtro == f ? Paleta.suelo : Paleta.tinta.withAlpha(180),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (lista.isEmpty)
              const Vacio('Sin resultados', 'Prueba otro filtro o crea una cotización nueva.')
            else
              for (final c in lista)
                FilaCot(c, alTocar: () => ir(context, DetalleCotizacion(c.n))),
          ],
        );
      },
    );
  }
}
