import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tienda.dart';
import '../widgets.dart';
import '../estilo.dart';

// Alta y edición de clientes. Al guardar devuelve el id del cliente
// (así el selector de cliente puede usarlo de inmediato).
class FormularioCliente extends StatefulWidget {
  final Cliente? editar;
  const FormularioCliente({super.key, this.editar});

  @override
  State<FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends State<FormularioCliente> {
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final telefono = TextEditingController();
  final notas = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.editar;
    if (c != null) {
      nombre.text = c.nombre;
      correo.text = c.correo;
      telefono.text = c.telefono;
      notas.text = c.notas;
    }
  }

  @override
  void dispose() {
    nombre.dispose();
    correo.dispose();
    telefono.dispose();
    notas.dispose();
    super.dispose();
  }

  void guardar() {
    final n = nombre.text.trim();
    final m = correo.text.trim();
    if (n.isEmpty) return mostrarAviso(context, 'Escribe el nombre del cliente');
    if (m.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(m)) {
      return mostrarAviso(context, 'Revisa el correo: falta @ o el dominio');
    }
    final c = widget.editar ?? Cliente(id: 0, nombre: n);
    c.nombre = n;
    c.correo = m;
    c.telefono = telefono.text.trim();
    c.notas = notas.text.trim();
    final id = tienda.guardarCliente(c);
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra(widget.editar == null ? 'Nuevo cliente' : 'Editar cliente'),
      body: ListView(
        // Márgenes del Home (22) y espacio generoso entre campos.
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          TextField(
            controller: nombre,
            textCapitalization: TextCapitalization.words,
            decoration: decoracionCampo('Nombre o empresa', ayuda: 'Ej. Café Origen S.A.S.'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: correo,
            keyboardType: TextInputType.emailAddress,
            decoration: decoracionCampo('Correo', ayuda: 'contacto@empresa.co'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: telefono,
            keyboardType: TextInputType.phone,
            decoration: decoracionCampo('Teléfono / WhatsApp', ayuda: '300 000 0000'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notas,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('Notas (opcional)'),
          ),
          const SizedBox(height: 22),
          BotonClaqueta('Guardar cliente', guardar),
          const SizedBox(height: 10),
          BotonClaqueta('Cancelar', () => Navigator.pop(context), tipo: 'secundario'),
        ],
      ),
    );
  }
}
