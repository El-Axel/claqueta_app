import 'package:flutter/material.dart';
import 'tema.dart';
import 'tienda.dart';
import 'widgets.dart';
import 'pantallas/formulario_cliente.dart';
import 'servicios/nube.dart';
import 'servicios/ubicacion.dart';
import 'util.dart';

/// Entra a la nube con Google (para quien empezó con Google) y sincroniza.
/// No interrumpe si falla: la app sigue funcionando en el teléfono.
Future<void> conectarNube(BuildContext context) async {
  if (!servicioNube.configurada) return;
  try {
    await servicioNube.conectar();
  } catch (e) {
    if (context.mounted) {
      mostrarAviso(context, 'Nube: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    return;
  }
  if (context.mounted) await sincronizarCuenta(context);
}

/// Con la cuenta ya abierta, decide qué hacer con los datos:
/// - Si este teléfono tenía datos de OTRA cuenta, se vacían (solo aquí).
/// - Nube vacía: sube los datos de este teléfono.
/// - Teléfono vacío: trae los de la nube.
/// - Ambos con datos: pregunta (traer o reemplazar).
Future<void> sincronizarCuenta(BuildContext context) async {
  if (!servicioNube.conectada) return;
  try {
    final uid = servicioNube.uid;
    if (tienda.dueno.isNotEmpty && tienda.dueno != uid) tienda.vaciarLocal();
    tienda.fijarDueno(uid);
    final r = await servicioNube.resumen();
    if (r.vacia) {
      await servicioNube.subir();
      if (context.mounted) mostrarAviso(context, 'Tus datos quedaron guardados en la nube');
      return;
    }
    // Teléfono vacío (instalación nueva): se traen los datos sin preguntar,
    // para no ofrecer "reemplazar la nube" con nada.
    if (tienda.estaVacia) {
      await servicioNube.bajar();
      if (context.mounted) mostrarAviso(context, 'Recuperé tus datos de la nube');
      return;
    }
    if (!context.mounted) return;
    final fecha = r.actualizado == null ? '' : ' (última copia: ${fechaCorta(r.actualizado!)})';
    final traer = await hojaInferior<bool>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Encontré tus datos en la nube', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 6),
          Text(
            '${r.clientes} clientes, ${r.cotizaciones} cotizaciones y ${r.trabajos} trabajos$fecha.',
            style: estiloSuave(tamano: 13),
          ),
          const SizedBox(height: 16),
          BotonClaqueta('Traerlos a este teléfono', () => Navigator.pop(ctx, true),
              icono: Icons.cloud_download_outlined),
          const SizedBox(height: 10),
          BotonClaqueta('Reemplazarlos con los de este teléfono', () => Navigator.pop(ctx, false),
              tipo: 'secundario', icono: Icons.cloud_upload_outlined),
        ],
      ),
    );
    if (traer == true) {
      await servicioNube.bajar();
      if (context.mounted) mostrarAviso(context, 'Datos recuperados de la nube');
    } else if (traer == false) {
      await servicioNube.subir();
      if (context.mounted) mostrarAviso(context, 'La nube quedó con los datos de este teléfono');
    }
  } catch (e) {
    if (context.mounted) {
      mostrarAviso(context, 'Nube: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }
}

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
