import 'package:flutter/material.dart';
import 'tema.dart';
import 'tienda.dart';
import 'widgets.dart';
import 'pantallas/formulario_cliente.dart';
import 'servicios/ubicacion.dart';

/// Hoja "¿En qué ciudad trabajas?": fija la zona de búsqueda a mano.
/// Se usa cuando no hay permiso de ubicación o el teléfono no la da.
Future<void> elegirCiudad(BuildContext context, {String? motivo}) async {
  final c = TextEditingController(text: tienda.config.ciudad);
  final nombre = await hojaInferior<String>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿En qué ciudad trabajas?', style: estiloDisplay(tamano: 16)),
        const SizedBox(height: 4),
        Text(motivo ?? 'Al buscar direcciones saldrán primero los lugares de esa ciudad.',
            style: estiloSuave(tamano: 13)),
        const SizedBox(height: 14),
        TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: decoracionCampo('Ciudad (ej. Pereira)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        const SizedBox(height: 14),
        BotonClaqueta('Guardar ciudad', () => Navigator.pop(ctx, c.text)),
      ],
    ),
  );
  if (nombre == null || nombre.trim().isEmpty || !context.mounted) return;
  try {
    final guardada = await fijarCiudad(nombre);
    if (context.mounted) mostrarAviso(context, 'Buscando lugares cerca de $guardada');
  } catch (e) {
    if (context.mounted) mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

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
