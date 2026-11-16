import 'package:flutter/material.dart';
import '../modelos.dart';
import '../selectores.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_cotizacion.dart';
import '../estilo.dart';

// Crear o editar una cotización.
// Idea clave: el catálogo ya tiene los precios. Tú solo anotas lo que
// pide el cliente ("3 videos, 10 fotos...") y el total se arma solo.
class NuevaCotizacion extends StatefulWidget {
  final Cotizacion? editar;
  final int? clienteId;

  const NuevaCotizacion({super.key, this.editar, this.clienteId});

  @override
  State<NuevaCotizacion> createState() => _NuevaCotizacionState();
}

class _NuevaCotizacionState extends State<NuevaCotizacion> {
  int? clienteId;
  final proyecto = TextEditingController();
  final notas = TextEditingController();
  final Map<int, int> cantidades = {}; // id de servicio -> cantidad
  final List<ItemCot> personalizados = []; // ítems que no están en el catálogo
  int descuento = 0;
  bool iva = false;
  String? paqueteAplicado;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e == null) {
      clienteId = widget.clienteId;
      iva = tienda.config.iva;
      return;
    }
    clienteId = e.clienteId;
    proyecto.text = e.proyecto;
    notas.text = e.notas;
    descuento = e.descuento;
    iva = e.iva;
    for (final i in e.items) {
      Servicio? coincide;
      for (final s in tienda.servicios) {
        if (s.nombre == i.descripcion && s.precio == i.precio) coincide = s;
      }
      if (coincide != null) {
        cantidades[coincide.id] = (cantidades[coincide.id] ?? 0) + i.cantidad;
      } else {
        personalizados.add(ItemCot(
            descripcion: i.descripcion, unidad: i.unidad, precio: i.precio, cantidad: i.cantidad));
      }
    }
  }

  @override
  void dispose() {
    proyecto.dispose();
    notas.dispose();
    super.dispose();
  }

  // Ítems resultantes (los del catálogo con cantidad > 0 + los personalizados)
  List<ItemCot> construirItems() {
    final items = <ItemCot>[];
    for (final s in tienda.servicios) {
      final q = cantidades[s.id] ?? 0;
      if (q > 0) {
        items.add(ItemCot(descripcion: s.nombre, unidad: s.unidad, precio: s.precio, cantidad: q));
      }
    }
    items.addAll(personalizados);
    return items;
  }

  Cotizacion borrador() => Cotizacion(
        n: 0,
        clienteId: clienteId ?? 0,
        proyecto: proyecto.text.trim(),
        items: construirItems(),
        descuento: descuento,
        iva: iva,
        creada: DateTime.now(),
      );

  void aplicarPaquete(Paquete p) {
    setState(() {
      cantidades.clear();
      p.items.forEach((id, q) {
        if (tienda.servicio(id) != null) cantidades[id] = q;
      });
      descuento = p.descuento;
      paqueteAplicado = p.nombre;
    });
  }

  Future<void> agregarPersonalizado() async {
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final ok = await hojaInferior<bool>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ítem personalizado', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 4),
          Text('Para algo que no está en tu catálogo.', style: estiloSuave(tamano: 13)),
          const SizedBox(height: 16),
          TextField(controller: nombre, decoration: decoracionCampo('Descripción')),
          const SizedBox(height: 12),
          TextField(
            controller: precio,
            keyboardType: TextInputType.number,
            decoration: decoracionCampo('Precio (COP)'),
          ),
          const SizedBox(height: 16),
          BotonClaqueta('Agregar', () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      final valor = int.tryParse(precio.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (nombre.text.trim().isEmpty || valor <= 0) {
        if (mounted) mostrarAviso(context, 'Escribe una descripción y un precio válido');
      } else {
        setState(() => personalizados.add(
            ItemCot(descripcion: nombre.text.trim(), precio: valor, cantidad: 1)));
      }
    }
  }

  void guardar() {
    if (clienteId == null) return mostrarAviso(context, 'Elige un cliente');
    if (proyecto.text.trim().isEmpty) return mostrarAviso(context, 'Escribe el nombre del proyecto');
    final items = construirItems();
    if (items.isEmpty) return mostrarAviso(context, 'Agrega al menos un servicio');

    int n;
    final e = widget.editar;
    if (e != null) {
      e.clienteId = clienteId!;
      e.proyecto = proyecto.text.trim();
      e.items = items;
      e.descuento = descuento;
      e.iva = iva;
      e.notas = notas.text.trim();
      n = tienda.guardarCotizacion(e);
    } else {
      final c = Cotizacion(
        n: 0,
        clienteId: clienteId!,
        proyecto: proyecto.text.trim(),
        items: items,
        descuento: descuento,
        iva: iva,
        notas: notas.text.trim(),
        creada: DateTime.now(),
        vigenciaDias: tienda.config.vigenciaDias,
      );
      n = tienda.guardarCotizacion(c);
    }
    if (e != null) {
      // Al editar, la pantalla de detalle ya está debajo y se actualiza sola.
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => DetalleCotizacion(n)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cl = clienteId == null ? null : tienda.cliente(clienteId!);
    final previa = borrador();

    return Lienzo(
      appBar: barra(widget.editar == null
          ? 'Nueva cotización'
          : 'Editar ${folio(widget.editar!.n)}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          CampoSelector(
            etiqueta: 'Cliente',
            valor: cl?.nombre,
            ayuda: 'Elegir cliente',
            icono: Icons.person_outline,
            alTocar: () async {
              final id = await elegirCliente(context);
              if (id != null && mounted) setState(() => clienteId = id);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: proyecto,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: decoracionCampo('Proyecto', ayuda: 'Ej. Comercial 30 segundos'),
          ),
          if (tienda.paquetes.isNotEmpty) ...[
            const TituloSeccion('Empezar con un paquete'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in tienda.paquetes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text('${p.nombre} · ${formatearPesos(tienda.precioPaquete(p))}'),
                        backgroundColor: paqueteAplicado == p.nombre
                            ? Paleta.teal.withAlpha(60)
                            : Colors.white.withAlpha(18),
                        side: BorderSide(color: Colors.white.withAlpha(50)),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        onPressed: () => aplicarPaquete(p),
                      ),
                    ),
                ],
              ),
            ),
            if (paqueteAplicado != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Paquete "$paqueteAplicado" aplicado. Puedes ajustar las cantidades abajo.',
                  style: estiloSuave(tamano: 12),
                ),
              ),
          ],
          const TituloSeccion('Lo que pide el cliente'),
          if (tienda.servicios.isEmpty)
            const Vacio('Catálogo vacío', 'Agrega servicios en Catálogo y paquetes.')
          else
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
                                Text(s.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('${formatearPesos(s.precio)} por ${s.unidad}',
                                    style: const TextStyle(color: Paleta.arena, fontSize: 12)),
                              ],
                            ),
                          ),
                          Cantidad(
                            valor: cantidades[s.id] ?? 0,
                            cambio: (v) => setState(() {
                              cantidades[s.id] = v;
                              paqueteAplicado = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          for (int i = 0; i < personalizados.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Panel(
                relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(personalizados[i].descripcion,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${formatearPesos(personalizados[i].precio)} · personalizado',
                              style: const TextStyle(color: Paleta.arena, fontSize: 12)),
                        ],
                      ),
                    ),
                    Cantidad(
                      valor: personalizados[i].cantidad,
                      minimo: 1,
                      cambio: (v) => setState(() => personalizados[i].cantidad = v),
                    ),
                    IconButton(
                      onPressed: () => setState(() => personalizados.removeAt(i)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          BotonClaqueta('Agregar ítem personalizado', agregarPersonalizado,
              tipo: 'secundario', icono: Icons.add),
          const TituloSeccion('Ajustes de precio'),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Descuento', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('$descuento%', style: const TextStyle(color: Paleta.arena, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    Cantidad(
                      valor: descuento,
                      paso: 5,
                      cambio: (v) => setState(() => descuento = v > 50 ? 50 : v),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Incluir IVA 19%', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: iva,
                      activeColor: Paleta.teal,
                      onChanged: (v) => setState(() => iva = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notas,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('Notas para el cliente (opcional)',
                ayuda: 'Condiciones, forma de pago, entrega...'),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              children: [
                FilaDato('Subtotal', formatearPesos(previa.subtotal)),
                if (descuento > 0)
                  FilaDato('Descuento $descuento%', '-${formatearPesos(previa.valorDescuento)}',
                      colorValor: Paleta.durazno),
                if (iva) FilaDato('IVA 19%', formatearPesos(previa.valorIva)),
                const Divider(color: Colors.white24, height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total (COP)', style: TextStyle(fontWeight: FontWeight.w700)),
                    textoPesos(previa.total),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BotonClaqueta(widget.editar == null ? 'Guardar cotización' : 'Guardar cambios', guardar),
          const SizedBox(height: 10),
          BotonClaqueta('Cancelar', () => Navigator.pop(context), tipo: 'secundario'),
        ],
      ),
    );
  }
}
