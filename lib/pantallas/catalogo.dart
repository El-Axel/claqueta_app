import 'package:flutter/material.dart';
import '../modelos.dart';
import '../pdf_documentos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'pdf_vista.dart';
import '../estilo.dart';

// Catálogo: los servicios con su precio por unidad y los paquetes.
// Aquí viven TODOS los precios; las cotizaciones los toman de aquí.
class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  int vista = 0; // 0 = servicios, 1 = paquetes

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        return Lienzo(
          appBar: barra('Catálogo', acciones: [
            IconButton(
              tooltip: 'Catálogo en PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => ir(
                context,
                PdfVista(
                  titulo: 'Catálogo en PDF',
                  archivo: 'catalogo-claqueta.pdf',
                  construir: pdfCatalogo,
                ),
              ),
            ),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
            children: [
              const Aviso(
                'Los precios de ejemplo son un punto de partida: edítalos con tus tarifas reales.',
                icono: Icons.edit_note,
                color: Paleta.arena,
              ),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Servicios')),
                  ButtonSegment(value: 1, label: Text('Paquetes')),
                ],
                selected: {vista},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => vista = s.first),
              ),
              const SizedBox(height: 16),
              if (vista == 0) ..._servicios(context) else ..._paquetes(context),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _servicios(BuildContext context) {
    return [
      BotonClaqueta('Nuevo servicio', () => _formularioServicio(context, null), icono: Icons.add),
      const SizedBox(height: 14),
      if (tienda.servicios.isEmpty)
        const Vacio('Sin servicios', 'Agrega tu primer servicio con su precio.')
      else
        for (final s in tienda.servicios)
          FilaItem(
            titulo: s.nombre,
            subtitulo: 'por ${s.unidad}',
            derecha: formatearPesos(s.precio),
            alTocar: () => _formularioServicio(context, s),
          ),
    ];
  }

  List<Widget> _paquetes(BuildContext context) {
    return [
      BotonClaqueta('Nuevo paquete', () => ir(context, const FormularioPaquete()), icono: Icons.add),
      const SizedBox(height: 14),
      if (tienda.paquetes.isEmpty)
        const Vacio('Sin paquetes', 'Un paquete agrupa servicios con un descuento opcional.')
      else
        for (final p in tienda.paquetes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              alTocar: () => ir(context, FormularioPaquete(editar: p)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre en Figtree negrita (como los títulos de tarjeta del
                  // Home); el precio es la única cifra en acento.
                  Row(
                    children: [
                      Expanded(
                          child: Text(p.nombre,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                      textoPesos(tienda.precioPaquete(p), tamano: 15),
                    ],
                  ),
                  if (p.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(p.descripcion, style: estiloSuave(tamano: 13)),
                  ],
                  const SizedBox(height: 12),
                  // Servicios del paquete en píldoras neutras (antes teal).
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in p.items.entries)
                        if (tienda.servicio(e.key) != null)
                          Etiqueta('${tienda.servicio(e.key)!.nombre} x${e.value}',
                              color: Paleta.tinta.withAlpha(200)),
                      if (p.descuento > 0) Etiqueta('${p.descuento}% desc.', color: Paleta.arena),
                    ],
                  ),
                ],
              ),
            ),
          ),
    ];
  }

  Future<void> _formularioServicio(BuildContext context, Servicio? s) async {
    final nombre = TextEditingController(text: s?.nombre ?? '');
    final precio = TextEditingController(text: s == null ? '' : s.precio.toString());
    String unidad = s?.unidad ?? 'día';
    const unidades = ['día', 'hora', 'video', 'foto', 'servicio'];

    final accion = await hojaInferior<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s == null ? 'Nuevo servicio' : 'Editar servicio', style: estiloDisplay(tamano: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracionCampo('Nombre', ayuda: 'Ej. Edición de video'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precio,
              keyboardType: TextInputType.number,
              decoration: decoracionCampo('Precio por unidad (COP)'),
            ),
            const SizedBox(height: 14),
            const EtiquetaSeccion('Cobras por'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final u in unidades)
                  ChoiceChip(
                    label: Text(u),
                    selected: unidad == u,
                    selectedColor: Paleta.arena, // acento único (antes teal)
                    showCheckmark: false,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: unidad == u ? Paleta.suelo : Paleta.tinta),
                    onSelected: (_) => setHoja(() => unidad = u),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            BotonClaqueta('Guardar', () => Navigator.pop(ctx, 'guardar')),
            if (s != null) ...[
              const SizedBox(height: 10),
              BotonClaqueta('Eliminar servicio', () => Navigator.pop(ctx, 'eliminar'),
                  tipo: 'peligro'),
            ],
          ],
        ),
      ),
    );

    final valor = int.tryParse(precio.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final nombreFinal = nombre.text.trim();
    if (!context.mounted || accion == null) return;

    if (accion == 'eliminar' && s != null) {
      final ok = await confirmar(context,
          titulo: '¿Eliminar "${s.nombre}"?',
          mensaje: 'Se quitará también de los paquetes. Las cotizaciones ya hechas no cambian.',
          boton: 'Eliminar',
          peligro: true);
      if (ok) tienda.eliminarServicio(s.id);
      return;
    }
    if (nombreFinal.isEmpty || valor <= 0) {
      mostrarAviso(context, 'Escribe un nombre y un precio válido');
      return;
    }
    if (s == null) {
      tienda.guardarServicio(Servicio(id: 0, nombre: nombreFinal, unidad: unidad, precio: valor));
    } else {
      s.nombre = nombreFinal;
      s.unidad = unidad;
      s.precio = valor;
      tienda.guardarServicio(s);
    }
  }
}

// ---------------------------------------------------------------
// Formulario de paquete: nombre, descripción, servicios con cantidad
// y descuento. Muestra el precio final mientras lo armas.
// ---------------------------------------------------------------
class FormularioPaquete extends StatefulWidget {
  final Paquete? editar;
  const FormularioPaquete({super.key, this.editar});

  @override
  State<FormularioPaquete> createState() => _FormularioPaqueteState();
}

class _FormularioPaqueteState extends State<FormularioPaquete> {
  final nombre = TextEditingController();
  final descripcion = TextEditingController();
  final Map<int, int> cantidades = {};
  int descuento = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.editar;
    if (p != null) {
      nombre.text = p.nombre;
      descripcion.text = p.descripcion;
      cantidades.addAll(p.items);
      descuento = p.descuento;
    }
  }

  @override
  void dispose() {
    nombre.dispose();
    descripcion.dispose();
    super.dispose();
  }

  Paquete armar() => Paquete(
        id: widget.editar?.id ?? 0,
        nombre: nombre.text.trim(),
        descripcion: descripcion.text.trim(),
        items: {
          for (final e in cantidades.entries)
            if (e.value > 0) e.key: e.value
        },
        descuento: descuento,
      );

  void guardar() {
    final p = armar();
    if (p.nombre.isEmpty) return mostrarAviso(context, 'Ponle un nombre al paquete');
    if (p.items.isEmpty) return mostrarAviso(context, 'Agrega al menos un servicio');
    tienda.guardarPaquete(p);
    Navigator.pop(context);
  }

  Future<void> eliminar() async {
    final ok = await confirmar(context,
        titulo: '¿Eliminar este paquete?',
        mensaje: 'Los servicios del catálogo no se borran.',
        boton: 'Eliminar',
        peligro: true);
    if (ok && mounted) {
      tienda.eliminarPaquete(widget.editar!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = armar();
    final base = tienda.precioBasePaquete(p);
    return Lienzo(
      appBar: barra(widget.editar == null ? 'Nuevo paquete' : 'Editar paquete'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          TextField(
            controller: nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('Nombre del paquete', ayuda: 'Ej. Comercial básico'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descripcion,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('Descripción', ayuda: 'Qué incluye, en una frase'),
          ),
          const TituloSeccion('Servicios incluidos'),
          Panel(
            relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final s in tienda.servicios)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                              // Precio tenue (el acento queda para el total).
                              Text('${formatearPesos(s.precio)} por ${s.unidad}',
                                  style: estiloSuave(tamano: 13)),
                            ],
                          ),
                        ),
                        Cantidad(
                          valor: cantidades[s.id] ?? 0,
                          cambio: (v) => setState(() => cantidades[s.id] = v),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const TituloSeccion('Descuento del paquete'),
          Panel(
            child: Row(
              children: [
                const Expanded(child: Text('Descuento', style: TextStyle(fontWeight: FontWeight.w700))),
                Text('$descuento%', style: const TextStyle(color: Paleta.arena, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Cantidad(
                  valor: descuento,
                  paso: 5,
                  cambio: (v) => setState(() => descuento = v > 50 ? 50 : v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              children: [
                FilaDato('Suma de servicios', formatearPesos(base)),
                if (descuento > 0)
                  FilaDato('Descuento $descuento%', '-${formatearPesos(base - tienda.precioPaquete(p))}',
                      colorValor: Paleta.tinta.withAlpha(170)),
                const Divider(height: 22),
                Row(
                  children: [
                    const Expanded(child: EtiquetaSeccion('Precio del paquete')),
                    textoPesos(tienda.precioPaquete(p)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BotonClaqueta('Guardar paquete', guardar),
          if (widget.editar != null) ...[
            const SizedBox(height: 10),
            BotonClaqueta('Eliminar paquete', eliminar, tipo: 'peligro'),
          ],
        ],
      ),
    );
  }
}
