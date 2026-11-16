import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../compartir.dart';
import '../modelos.dart';
import '../pdf_documentos.dart';
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
  late final Cotizacion cot;
  late final Cliente cli;

  @override
  void initState() {
    super.initState();
    cot = tienda.cotizacion(widget.n)!;
    cli = tienda.cliente(cot.clienteId);
    mensaje = TextEditingController(
      text: widget.recordatorio
          ? mensajeRecordatorio(cot, cli, tienda.config)
          : mensajeCotizacion(cot, cli, tienda.config),
    );
  }

  @override
  void dispose() {
    mensaje.dispose();
    super.dispose();
  }

  Future<void> compartirPdf({bool conCorreo = false}) async {
    final bytes = await pdfCotizacion(cot);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${folio(cot.n)}.pdf',
      subject: asuntoCotizacion(cot),
      body: mensaje.text,
      emails: conCorreo && cli.correo.isNotEmpty ? [cli.correo] : null,
    );
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
    if (!ok) {
      mostrarAviso(context, cli.correo.isEmpty
          ? 'Este cliente no tiene correo guardado'
          : 'No se pudo abrir el correo');
    }
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
            child: Panel(
              color: Paleta.panel2,
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Paleta.terracota),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${folio(cot.n)}.pdf', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('Toca para ver cómo queda', style: estiloSuave()),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
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
          BotonClaqueta(gmail ? 'Correo con PDF adjunto' : 'Gmail desactivado en Ajustes',
              gmail ? () => compartirPdf(conCorreo: true) : null,
              icono: Icons.mail_outline),
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
