import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../compartir.dart';
import '../modelos.dart';
import '../pdf_documentos.dart';
import '../servicios/correo_html.dart';
import '../servicios/google_api.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'pdf_vista.dart';
import '../estilo.dart';

// Pantalla de envío: el mensaje queda personalizado y editable, y desde
// aquí se manda por correo (con el PDF) y/o por WhatsApp.
class EnvioCotizacion extends StatefulWidget {
  final int n;
  final bool recordatorio;
  const EnvioCotizacion(this.n, {super.key, this.recordatorio = false});

  @override
  State<EnvioCotizacion> createState() => _EnvioCotizacionState();
}

class _EnvioCotizacionState extends State<EnvioCotizacion> {
  late final TextEditingController mensaje;
  late final String _mensajeOriginal; // para saber si el usuario lo editó
  late final Cotizacion cot;
  late final Cliente cli;

  @override
  void initState() {
    super.initState();
    cot = tienda.cotizacion(widget.n)!;
    cli = tienda.cliente(cot.clienteId);
    _mensajeOriginal = widget.recordatorio
        ? mensajeRecordatorio(cot, cli, tienda.config)
        : mensajeCotizacion(cot, cli, tienda.config);
    mensaje = TextEditingController(text: _mensajeOriginal);
  }

  @override
  void dispose() {
    mensaje.dispose();
    super.dispose();
  }

  bool enviando = false;

  Future<void> compartirPdf({bool conCorreo = false}) async {
    try {
      final bytes = await pdfCotizacion(cot);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${folio(cot.n)}.pdf',
        subject: asuntoCotizacion(cot),
        body: mensaje.text,
        emails: conCorreo && cli.correo.isNotEmpty ? [cli.correo] : null,
      );
    } catch (_) {
      if (mounted) mostrarAviso(context, 'No se pudo abrir el menú para compartir');
    }
  }

  /// Envía el correo con el PDF adjunto usando la API de Gmail.
  /// Sin Google conectado, usa el menú Compartir del teléfono.
  Future<void> enviarPorGmail() async {
    if (cli.correo.isEmpty) {
      return mostrarAviso(context, 'Este cliente no tiene correo guardado');
    }
    if (!servicioGoogle.conectado) {
      if (servicioGoogle.real) {
        mostrarAviso(context, 'Inicia sesión con Google en Ajustes para enviar desde Gmail');
      }
      return compartirPdf(conCorreo: true);
    }
    final seguir = await confirmar(
      context,
      titulo: 'Enviar por Gmail',
      mensaje: 'Se enviará desde ${servicioGoogle.correo} a ${cli.correo} con ${folio(cot.n)}.pdf adjunto.',
      boton: 'Enviar',
    );
    if (!seguir || !mounted) return;
    setState(() => enviando = true);
    try {
      await servicioGoogle.enviarCorreo(
        para: cli.correo,
        asunto: asuntoCotizacion(cot),
        cuerpo: mensaje.text,
        // Versión con diseño. Si el usuario editó el mensaje, su texto
        // se muestra en el correo; si no, se usa el saludo de la plantilla.
        html: correoCotizacionHtml(
          c: cot,
          cl: cli,
          cfg: tienda.config,
          remitente: servicioGoogle.correo,
          recordatorio: widget.recordatorio,
          mensajePersonal: mensaje.text.trim() == _mensajeOriginal.trim() ? null : mensaje.text,
        ),
        pdf: await pdfCotizacion(cot),
        nombrePdf: '${folio(cot.n)}.pdf',
      );
      if (!mounted) return;
      if (cot.estado == estBorrador) tienda.cambiarEstado(cot.n, estEnviada);
      mostrarAviso(context, 'Correo enviado a ${cli.correo}');
    } catch (e) {
      if (mounted) mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Future<void> porWhatsApp() async {
    final ok = await abrirWhatsApp(cli.telefono, mensaje.text);
    if (!mounted) return;
    if (!ok) {
      mostrarAviso(context, cli.telefono.isEmpty
          ? 'Este cliente no tiene teléfono guardado'
          : 'No se pudo abrir WhatsApp');
    } else {
      mostrarAviso(context, 'Abre el chat y adjunta el PDF con "Compartir PDF"');
    }
  }

  Future<void> porCorreoSimple() async {
    final ok = await abrirCorreo(cli.correo, asuntoCotizacion(cot), mensaje.text);
    if (!mounted) return;
    mostrarAviso(
        context,
        !ok
            ? (cli.correo.isEmpty
                ? 'Este cliente no tiene correo guardado'
                : 'No se pudo abrir la app de correo')
            : 'Abriendo tu app de correo…');
  }

  void marcarEnviada() {
    tienda.cambiarEstado(cot.n, estEnviada);
    mostrarAviso(context, 'Marcada como enviada');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esBorrador = cot.estado == estBorrador;
    final gmail = tienda.integracion('gmail');
    return Lienzo(
      appBar: barra(widget.recordatorio ? 'Enviar recordatorio' : 'Enviar cotización'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          Panel(
            child: Column(
              children: [
                FilaDato('Para', cli.correo.isEmpty ? 'Sin correo' : cli.correo),
                FilaDato('WhatsApp', cli.telefono.isEmpty ? 'Sin teléfono' : cli.telefono),
                FilaDato('Asunto', asuntoCotizacion(cot)),
                FilaDato('Total', formatearPesos(cot.total), colorValor: Paleta.arena),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => ir(
              context,
              PdfVista(
                titulo: folio(cot.n),
                archivo: '${folio(cot.n)}.pdf',
                construir: () => pdfCotizacion(cot),
              ),
            ),
            // Tarjeta suave normal (sin tinte) y el ícono del PDF en arena,
            // como los atajos del Home: un solo acento por pantalla.
            child: Panel(
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Paleta.arena),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${folio(cot.n)}.pdf',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('Toca para ver cómo queda', style: estiloSuave(tamano: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Paleta.tinta.withAlpha(120)),
                ],
              ),
            ),
          ),
          const TituloSeccion('Mensaje (puedes editarlo)'),
          TextField(
            controller: mensaje,
            maxLines: 12,
            minLines: 8,
            decoration: decoracionCampo('Mensaje'),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: mensaje.text));
                if (mounted) mostrarAviso(context, 'Mensaje copiado');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar mensaje'),
            ),
          ),
          const TituloSeccion('Enviar'),
          BotonClaqueta(
              !gmail
                  ? 'Gmail desactivado en Ajustes'
                  : enviando
                      ? 'Enviando…'
                      : servicioGoogle.conectado
                          ? 'Enviar por Gmail con PDF'
                          : 'Correo con PDF adjunto',
              gmail && !enviando ? enviarPorGmail : null,
              icono: Icons.mail_outline),
          if (gmail && servicioGoogle.conectado) ...[
            const SizedBox(height: 4),
            Text('Sale desde ${servicioGoogle.correo}', style: estiloSuave(tamano: 12)),
          ],
          const SizedBox(height: 10),
          BotonClaqueta('WhatsApp con el mensaje', porWhatsApp,
              tipo: 'secundario', icono: Icons.chat_outlined),
          const SizedBox(height: 10),
          BotonClaqueta('Compartir PDF (WhatsApp, Drive...)', () => compartirPdf(),
              tipo: 'secundario', icono: Icons.ios_share),
          const SizedBox(height: 10),
          BotonClaqueta('Abrir en mi app de correo (sin PDF)', porCorreoSimple,
              tipo: 'secundario', icono: Icons.alternate_email),
          if (esBorrador) ...[
            const SizedBox(height: 22),
            Text('Cuando ya la hayas enviado, márcala para empezar el seguimiento.',
                style: estiloSuave(tamano: 13)),
            const SizedBox(height: 10),
            BotonClaqueta('Ya la envié: marcar como enviada', marcarEnviada,
                tipo: 'arena', icono: Icons.check),
          ],
        ],
      ),
    );
  }
}
