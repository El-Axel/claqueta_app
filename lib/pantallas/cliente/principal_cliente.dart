import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import 'cotizaciones_cliente.dart';
import 'inicio_cliente.dart';
import 'novedades_cliente.dart';
import 'piezas_cliente.dart';
import 'solicitar_cliente.dart';

// ---------------------------------------------------------------
// ESTRUCTURA DEL ESPACIO DEL CLIENTE: 4 pestañas con el mismo dock
// del realizador. IndexedStack conserva el scroll y el formulario de
// Solicitar a medio llenar al cambiar de pestaña.
// ---------------------------------------------------------------

const int _indiceNovedades = 3;

class PrincipalCliente extends StatelessWidget {
  const PrincipalCliente({super.key});

  static const List<List<dynamic>> items = [
    [Icons.home_outlined, Icons.home_rounded, 'Inicio'],
    [Icons.description_outlined, Icons.description, 'Cotizaciones'],
    [Icons.add_circle_outline, Icons.add_circle, 'Solicitar'],
    [Icons.notifications_none_rounded, Icons.notifications_rounded, 'Novedades'],
  ];

  void _elegir(int i) {
    if (i == _indiceNovedades) {
      // Se guarda cuántas eran nuevas antes de marcarlas como vistas.
      novedadesResaltadas.value = portal.noLeidas;
      portal.marcarNovedadesVistas();
    }
    pestanaCliente.value = i;
  }

  @override
  Widget build(BuildContext context) {
    const paginas = <Widget>[
      PestanaInicioCliente(),
      PestanaCotizacionesCliente(),
      PestanaSolicitarCliente(),
      PestanaNovedadesCliente(),
    ];
    return ListenableBuilder(
      // Escucha la pestaña y el portal: el contador de novedades cambia
      // cuando llegan datos nuevos aunque no se cambie de pestaña.
      listenable: Listenable.merge([pestanaCliente, portal]),
      builder: (context, _) {
        final actual = pestanaCliente.value;
        final sinLeer = portal.noLeidas;
        return Lienzo(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: actual, children: paginas),
          ),
          bottomNavigationBar: Stack(
            clipBehavior: Clip.none,
            children: [
              DockNav(actual: actual, alElegir: _elegir, items: items),
              // Contador sobre el círculo de Novedades. Es el último del
              // dock, así que su borde derecho es fijo: 16 de margen +
              // 1 de borde + 8 de relleno del dock.
              if (sinLeer > 0 && actual != _indiceNovedades)
                Positioned(
                  right: 19,
                  top: 3,
                  child: IgnorePointer(child: _Contador(sinLeer)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Círculo arena con el número de novedades sin leer.
class _Contador extends StatelessWidget {
  final int n;
  const _Contador(this.n);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Paleta.arena,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.suelo, width: 2),
      ),
      child: Text(
        n > 9 ? '9+' : '$n',
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: Paleta.suelo, height: 1),
      ),
    );
  }
}
