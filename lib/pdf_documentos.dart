import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'modelos.dart';
import 'tienda.dart';
import 'util.dart';

// ---------------------------------------------------------------
// Generación de PDF con la identidad del Pizarrón.
// Se usa la fuente que trae el paquete "pdf" (Helvetica), por eso
// el texto evita símbolos raros: solo letras, números y signos comunes.
// ---------------------------------------------------------------

const PdfColor _suelo = PdfColor.fromInt(0xFF0B1315);
const PdfColor _teal = PdfColor.fromInt(0xFF2EA690);
const PdfColor _arena = PdfColor.fromInt(0xFFF2C572);
const PdfColor _tinta = PdfColor.fromInt(0xFFF4F1EA);
const PdfColor _gris = PdfColor.fromInt(0xFF5A6B70);
const PdfColor _linea = PdfColor.fromInt(0xFFD9DFE0);

/// Isotipo de la marca (blanco) para el sello del encabezado. Si no se
/// puede leer (por ejemplo, en pruebas), se usa la letra "C".
Future<pw.MemoryImage?> _isotipo() async {
  try {
    final datos = await rootBundle.load('assets/icono/isotipo_blanco.png');
    return pw.MemoryImage(datos.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.Widget _encabezado(String titulo, String subtitulo, Config cfg, [pw.MemoryImage? logo]) {
  return pw.Container(
    padding: pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: _suelo,
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 44,
          height: 44,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _teal,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          padding: const pw.EdgeInsets.all(9),
          child: logo != null
              ? pw.Image(logo)
              : pw.Text('C',
                  style: pw.TextStyle(
                      color: _suelo, fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(cfg.negocio,
                  style: pw.TextStyle(
                      color: _tinta, fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(subtitulo, style: pw.TextStyle(color: _arena, fontSize: 9)),
            ],
          ),
        ),
        pw.Text(titulo,
            style: pw.TextStyle(
                color: _tinta, fontSize: 18, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _pie(Config cfg) {
  return pw.Column(children: [
    pw.Divider(color: _linea),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(cfg.negocio, style: pw.TextStyle(color: _gris, fontSize: 8)),
        pw.Text('Generado con Claqueta',
            style: pw.TextStyle(color: _gris, fontSize: 8)),
      ],
    ),
  ]);
}

pw.Widget _fila(String a, String b, {bool negrita = false, PdfColor? color}) {
  final estilo = pw.TextStyle(
    fontSize: negrita ? 13 : 10,
    fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color ?? _suelo,
  );
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(a, style: estilo), pw.Text(b, style: estilo)],
    ),
  );
}

pw.Widget _celda(String texto, double ancho,
    {bool derecha = false, bool cabecera = false}) {
  return pw.SizedBox(
    width: ancho,
    child: pw.Text(
      texto,
      textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: cabecera ? 8 : 10,
        fontWeight: cabecera ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: cabecera ? _gris : _suelo,
      ),
    ),
  );
}

/// PDF de una cotización.
Future<Uint8List> pdfCotizacion(Cotizacion c) async {
  final logo = await _isotipo();
  final cl = tienda.cliente(c.clienteId);
  final cfg = tienda.config;
  final doc = pw.Document(title: folio(c.n), author: cfg.negocio);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(36),
      footer: (ctx) => _pie(cfg),
      build: (ctx) => [
        _encabezado('COTIZACION', folio(c.n), cfg, logo),
        pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PARA', style: pw.TextStyle(color: _gris, fontSize: 8)),
                  pw.SizedBox(height: 3),
                  pw.Text(cl.nombre,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  if (cl.correo.isNotEmpty)
                    pw.Text(cl.correo, style: pw.TextStyle(fontSize: 9, color: _gris)),
                  if (cl.telefono.isNotEmpty)
                    pw.Text(cl.telefono, style: pw.TextStyle(fontSize: 9, color: _gris)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('FECHA', style: pw.TextStyle(color: _gris, fontSize: 8)),
                pw.Text(fechaLarga(c.enviada ?? c.creada), style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text('VIGENTE HASTA', style: pw.TextStyle(color: _gris, fontSize: 8)),
                pw.Text(fechaLarga(c.vence), style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('PROYECTO', style: pw.TextStyle(color: _gris, fontSize: 8)),
        pw.SizedBox(height: 3),
        pw.Text(c.proyecto, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        // Tabla de ítems
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: PdfColor.fromInt(0xFFEEF2F2),
          child: pw.Row(children: [
            _celda('DESCRIPCION', 230, cabecera: true),
            _celda('CANT.', 40, derecha: true, cabecera: true),
            _celda('PRECIO', 90, derecha: true, cabecera: true),
            _celda('SUBTOTAL', 90, derecha: true, cabecera: true),
          ]),
        ),
        for (final i in c.items)
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _linea, width: 0.6)),
            ),
            child: pw.Row(children: [
              _celda(i.descripcion, 230),
              _celda('${i.cantidad}', 40, derecha: true),
              _celda(formatearPesos(i.precio), 90, derecha: true),
              _celda(formatearPesos(i.subtotal), 90, derecha: true),
            ]),
          ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(children: [
              _fila('Subtotal', formatearPesos(c.subtotal)),
              if (c.descuento > 0)
                _fila('Descuento ${c.descuento}%', '-${formatearPesos(c.valorDescuento)}'),
              if (c.iva) _fila('IVA 19%', formatearPesos(c.valorIva)),
              pw.Divider(color: _linea),
              _fila('TOTAL (COP)', formatearPesos(c.total), negrita: true, color: _teal),
            ]),
          ),
        ),
        if (c.notas.trim().isNotEmpty) ...[
          pw.SizedBox(height: 22),
          pw.Text('NOTAS', style: pw.TextStyle(color: _gris, fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text(c.notas, style: pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 26),
        pw.Container(
          padding: pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFFF6E3),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'Esta cotizacion es valida por ${c.vigenciaDias} dias. Para aceptarla basta con responder este mensaje.',
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// PDF del catálogo: servicios con precio por unidad y paquetes.
Future<Uint8List> pdfCatalogo() async {
  final logo = await _isotipo();
  final cfg = tienda.config;
  final doc = pw.Document(title: 'Catalogo de servicios', author: cfg.negocio);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(36),
      footer: (ctx) => _pie(cfg),
      build: (ctx) => [
        _encabezado('CATALOGO', 'Servicios y paquetes', cfg, logo),
        pw.SizedBox(height: 22),
        pw.Text('PAQUETES', style: pw.TextStyle(color: _gris, fontSize: 9)),
        pw.SizedBox(height: 8),
        for (final p in tienda.paquetes)
          pw.Container(
            margin: pw.EdgeInsets.only(bottom: 10),
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _linea),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(p.nombre,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(formatearPesos(tienda.precioPaquete(p)),
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold, color: _teal)),
                  ],
                ),
                if (p.descripcion.isNotEmpty)
                  pw.Text(p.descripcion, style: pw.TextStyle(fontSize: 9, color: _gris)),
                pw.SizedBox(height: 6),
                for (final e in p.items.entries)
                  if (tienda.servicio(e.key) != null)
                    pw.Text(
                      '- ${tienda.servicio(e.key)!.nombre} x${e.value}',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                if (p.descuento > 0)
                  pw.Text('Incluye ${p.descuento}% de descuento',
                      style: pw.TextStyle(fontSize: 9, color: _gris)),
              ],
            ),
          ),
        pw.SizedBox(height: 14),
        pw.Text('SERVICIOS A LA CARTA', style: pw.TextStyle(color: _gris, fontSize: 9)),
        pw.SizedBox(height: 8),
        for (final s in tienda.servicios)
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _linea, width: 0.6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${s.nombre}  (por ${s.unidad})', style: pw.TextStyle(fontSize: 10)),
                pw.Text(formatearPesos(s.precio),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Precios en pesos colombianos (COP).${cfg.iva ? '' : ' No incluyen IVA.'}',
          style: pw.TextStyle(fontSize: 9, color: _gris),
        ),
      ],
    ),
  );
  return doc.save();
}
