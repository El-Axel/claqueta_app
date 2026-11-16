import 'package:flutter/material.dart';
import 'tema.dart';
import 'tienda.dart';
import 'widgets.dart';
import 'pantallas/formulario_cliente.dart';

/// Hoja para elegir un cliente (o crear uno nuevo). Devuelve el id elegido.
Future<int?> elegirCliente(BuildContext context) async {
  final r = await hojaInferior<int>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elegir cliente', style: estiloDisplay(tamano: 16)),
        const SizedBox(height: 14),
        for (final c in tienda.clientes)
          FilaItem(
            titulo: c.nombre,
            subtitulo: c.correo.isEmpty ? 'Sin correo' : c.correo,
            alTocar: () => Navigator.pop(ctx, c.id),
          ),
        const SizedBox(height: 4),
        BotonClaqueta('Nuevo cliente', () => Navigator.pop(ctx, -1),
            tipo: 'secundario', icono: Icons.add),
      ],
    ),
  );
  if (r == -1) {
    if (!context.mounted) return null;
    return Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const FormularioCliente()),
    );
  }
  return r;
}
