import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../tema.dart';
import '../widgets.dart';
import '../estilo.dart';

// Vista previa de un PDF con botones para compartir o imprimir.
// Sirve para la cotización y para el catálogo (recibe cómo construirlo).
class PdfVista extends StatelessWidget {
  final String titulo;
  final String archivo;
  final Future<Uint8List> Function() construir;

  const PdfVista({
    super.key,
    required this.titulo,
    required this.archivo,
    required this.construir,
  });

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra(titulo),
      body: PdfPreview(
        build: (formato) => construir(),
        pdfFileName: archivo,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        scrollViewDecoration: const BoxDecoration(color: Paleta.suelo),
      ),
    );
  }
}
