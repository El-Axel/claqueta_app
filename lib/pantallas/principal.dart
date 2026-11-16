import 'package:flutter/material.dart';
import 'inicio.dart';
import 'cotizar.dart';
import 'agenda.dart';
import 'finanzas.dart';
import 'clientes.dart';
import '../estilo.dart';

// Pestaña activa. Es global para que cualquier pantalla pueda
// "saltar" a otra pestaña (por ejemplo, Inicio -> Finanzas).
final ValueNotifier<int> pestana = ValueNotifier<int>(0);

// Estructura principal: las 5 pestañas con la barra de navegación abajo.
// IndexedStack mantiene viva cada pestaña (conserva scroll y búsquedas).
class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    const paginas = <Widget>[
      PestanaInicio(),
      PestanaCotizar(),
      PestanaAgenda(),
      PestanaFinanzas(),
      PestanaClientes(),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: pestana,
      builder: (context, actual, _) {
        return Lienzo(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: actual, children: paginas),
          ),
          bottomNavigationBar: DockNav(
            actual: actual,
            alElegir: (i) => pestana.value = i,
          ),
        );
      },
    );
  }
}
