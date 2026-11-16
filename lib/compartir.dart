import 'package:url_launcher/url_launcher.dart';
import 'modelos.dart';
import 'util.dart';

// ---------------------------------------------------------------
// Mensajes listos para enviar y funciones que abren WhatsApp o el correo.
// Nota: WhatsApp (sin la API de pago) no permite adjuntar el PDF desde un
// enlace; por eso el PDF se comparte aparte con el menú "Compartir" del
// teléfono y el enlace de WhatsApp lleva el mensaje ya escrito.
// ---------------------------------------------------------------

String mensajeCotizacion(Cotizacion c, Cliente cl, Config cfg) {
  final b = StringBuffer();
  b.writeln('Hola ${cl.nombre}, un gusto saludarte.');
  b.writeln();
  b.writeln('Te comparto la cotización ${folio(c.n)} del proyecto "${c.proyecto}":');
  for (final i in c.items) {
    b.writeln('- ${i.descripcion}${i.cantidad > 1 ? ' x${i.cantidad}' : ''}: ${formatearPesos(i.subtotal)}');
  }
  if (c.descuento > 0) b.writeln('Descuento ${c.descuento}%: -${formatearPesos(c.valorDescuento)}');
  if (c.iva) b.writeln('IVA 19%: ${formatearPesos(c.valorIva)}');
  b.writeln();
  b.writeln('Total: ${formatearPesos(c.total)} COP');
  b.writeln('Vigente por ${c.vigenciaDias} días.');
  b.writeln();
  b.writeln('Quedo atento a tus comentarios.');
  b.write(cfg.negocio);
  return b.toString();
}

String mensajeRecordatorio(Cotizacion c, Cliente cl, Config cfg) {
  final dias = c.enviada == null ? 0 : diasDesde(c.enviada!);
  return 'Hola ${cl.nombre}, ¿cómo vas? Te escribo para saber si pudiste revisar la '
      'cotización ${folio(c.n)} de "${c.proyecto}" (${formatearPesos(c.total)}) que te envié '
      'hace $dias días. Si quieres ajustamos alcance o fechas. ${cfg.negocio}';
}

String asuntoCotizacion(Cotizacion c) => 'Cotización ${folio(c.n)} - ${c.proyecto}';

String mensajeAgenda(Trabajo t, Cliente cl, Config cfg) {
  final clima = climaDe(t.fecha);
  return 'Hola ${cl.nombre}, te confirmo el rodaje "${t.titulo}":\n'
      '${fechaLarga(t.fecha)}, ${hora12(t.hora)}\n'
      'Lugar: ${t.lugar}${t.zona.isEmpty ? '' : ' (${t.zona})'}\n'
      'Clima previsto: ${clima.temperatura}° ${clima.descripcion}, lluvia ${clima.lluvia}%.\n'
      '${cfg.negocio}';
}

Future<bool> abrirWhatsApp(String telefono, String texto) async {
  final digitos = telefonoParaWhatsApp(telefono);
  if (digitos.isEmpty) return false;
  final uri = Uri.parse('https://wa.me/$digitos?text=${Uri.encodeComponent(texto)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> abrirCorreo(String correo, String asunto, String cuerpo) async {
  if (correo.isEmpty) return false;
  final uri = Uri.parse(
      'mailto:$correo?subject=${Uri.encodeComponent(asunto)}&body=${Uri.encodeComponent(cuerpo)}');
  try {
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}
