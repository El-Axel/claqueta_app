import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_cliente.dart';
import 'formulario_cliente.dart';
import '../estilo.dart';

class PestanaClientes extends StatefulWidget {
  const PestanaClientes({super.key});

  @override
  State<PestanaClientes> createState() => _PestanaClientesState();
}

class _PestanaClientesState extends State<PestanaClientes> {
  String busqueda = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final q = busqueda.toLowerCase();
        final lista = tienda.clientes
            .where((c) => q.isEmpty || c.nombre.toLowerCase().contains(q))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          children: [
            Row(
              children: [
                Expanded(
                  child: Encabezado('Clientes', subtitulo: '${tienda.clientes.length} clientes'),
                ),
                BotonCirculo(Icons.person_add_alt_1_outlined,
                    () => ir(context, const FormularioCliente())),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => busqueda = v),
              decoration: decoracionCampo('Buscar por nombre o empresa',
                  icono: const Icon(Icons.search, size: 20)),
            ),
            const SizedBox(height: 14),
            if (lista.isEmpty)
              const Vacio('Sin resultados', 'Ningún cliente coincide con la búsqueda.')
            else
              for (final c in lista)
                FilaItem(
                  titulo: c.nombre,
                  subtitulo: c.correo.isEmpty ? 'Sin correo' : c.correo,
                  derecha:
                      '${tienda.cotizaciones.where((x) => x.clienteId == c.id).length} cot.',
                  derecha2: formatearPesos(tienda.cotizaciones
                      .where((x) => x.clienteId == c.id && x.estado == estAceptada)
                      .fold<int>(0, (a, x) => a + x.total)),
                  alTocar: () => ir(context, DetalleCliente(c.id)),
                ),
            const SizedBox(height: 10),
            BotonClaqueta('Nuevo cliente', () => ir(context, const FormularioCliente())),
          ],
        );
      },
    );
  }
}
