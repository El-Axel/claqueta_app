import 'package:flutter/material.dart';

import '../../estilo.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../util.dart';
import '../../widgets.dart';
import 'piezas_cliente.dart';

// ---------------------------------------------------------------
// SOLICITAR: el cliente pide una cotización nueva. Solo el tipo es
// obligatorio (para no frenar al cliente); el resto ayuda al
// realizador a cotizar más rápido. Debajo, el historial de pedidos.
// ---------------------------------------------------------------

const List<String> tiposProyecto = [
  'Video corporativo',
  'Fotografía',
  'Evento',
  'Videoclip',
  'Redes sociales',
  'Otro',
];

class PestanaSolicitarCliente extends StatefulWidget {
  const PestanaSolicitarCliente({super.key});

  @override
  State<PestanaSolicitarCliente> createState() => _PestanaSolicitarClienteState();
}

class _PestanaSolicitarClienteState extends State<PestanaSolicitarCliente> {
  String? _tipo;
  DateTime? _fecha;
  final _descripcion = TextEditingController();
  final _lugar = TextEditingController();
  bool _enviando = false;
  bool _faltaTipo = false;

  @override
  void dispose() {
    _descripcion.dispose();
    _lugar.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = soloFecha(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy.add(const Duration(days: 7)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 730)),
    );
    if (d != null && mounted) setState(() => _fecha = d);
  }

  Future<void> _enviar() async {
    if (_tipo == null) {
      setState(() => _faltaTipo = true);
      mostrarAviso(context, 'Elige el tipo de proyecto');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);
    try {
      await portal.solicitar(
        tipo: _tipo!,
        descripcion: _descripcion.text,
        fecha: _fecha,
        lugar: _lugar.text,
      );
      if (!mounted) return;
      // Formulario limpio para la próxima solicitud.
      setState(() {
        _tipo = null;
        _fecha = null;
        _descripcion.clear();
        _lugar.clear();
      });
      mostrarAviso(context, 'Solicitud enviada. ${nombreRealizador()} te enviará la cotización.');
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: portal,
      builder: (context, _) => ListaPortal([
        CabeceraCliente('Solicitar',
            subtitulo: 'Pídele una cotización nueva a ${nombreRealizador()}'),
        const EstadoPortal(),
        TarjetaSuave(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EtiquetaSeccion(_faltaTipo && _tipo == null
                  ? 'Tipo de proyecto · obligatorio'
                  : 'Tipo de proyecto'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tiposProyecto)
                    ChoiceChip(
                      label: Text(t),
                      selected: _tipo == t,
                      selectedColor: Paleta.arena,
                      showCheckmark: false,
                      side: BorderSide(
                          color: _faltaTipo && _tipo == null
                              ? Paleta.terracota.withAlpha(120)
                              : Colors.white.withAlpha(22)),
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _tipo == t ? Paleta.suelo : Paleta.tinta),
                      onSelected: _enviando
                          ? null
                          : (_) => setState(() {
                                _tipo = t;
                                _faltaTipo = false;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _descripcion,
                enabled: !_enviando,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracionCampo('Cuéntanos tu idea (opcional)',
                    ayuda: 'Qué necesitas, duración, para qué lo usarás…'),
              ),
              const SizedBox(height: 12),
              CampoSelector(
                etiqueta: 'Fecha tentativa (opcional)',
                valor: _fecha == null ? null : fechaLarga(_fecha!),
                ayuda: 'Elegir una fecha',
                icono: Icons.event_outlined,
                alTocar: _enviando ? () {} : _elegirFecha,
              ),
              if (_fecha != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _enviando ? null : () => setState(() => _fecha = null),
                    child: const Text('Quitar fecha'),
                  ),
                )
              else
                const SizedBox(height: 12),
              TextField(
                controller: _lugar,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracionCampo('Lugar (opcional)',
                    ayuda: 'Ciudad o sitio del rodaje',
                    icono: const Icon(Icons.place_outlined)),
              ),
              const SizedBox(height: 18),
              BotonClaqueta(
                _enviando ? 'Enviando…' : 'Enviar solicitud',
                _enviando ? null : _enviar,
                icono: _enviando ? null : Icons.send_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const TituloSeccion('Mis solicitudes'),
        if (portal.cargando && portal.solicitudes.isEmpty)
          const CargandoPortal(texto: 'Buscando tus solicitudes…')
        else if (portal.solicitudes.isEmpty)
          const Vacio('Sin solicitudes', 'Las cotizaciones que pidas aparecerán aquí con su estado.')
        else
          for (final s in portal.solicitudes) _FilaSolicitud(s),
      ]),
    );
  }
}

/// Renglón de una solicitud: tipo, cuándo se pidió, detalles y estado.
class _FilaSolicitud extends StatelessWidget {
  final Map<String, dynamic> s;
  const _FilaSolicitud(this.s);

  @override
  Widget build(BuildContext context) {
    final estado = (s['estado'] as String?) ?? 'Nueva';
    final creada = fechaDeTexto(s['creada']);
    final tentativa = DateTime.tryParse(s['fecha_tentativa'] as String? ?? '');
    final descripcion = (s['descripcion'] as String?)?.trim() ?? '';
    final detalles = [
      if (creada != null) 'Pedida ${fechaRelativa(creada)}',
      if (tentativa != null) 'para el ${fechaCorta(tentativa)}',
      if ((s['lugar'] as String?)?.trim().isNotEmpty == true) s['lugar'] as String,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        relleno: const EdgeInsets.all(14),
        radio: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withAlpha(14),
              ),
              child: Icon(Icons.movie_creation_outlined,
                  size: 20, color: Paleta.tinta.withAlpha(200)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((s['tipo'] as String?) ?? 'Solicitud',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (detalles.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detalles,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: estiloSuave(tamano: 12.5)),
                  ],
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Paleta.tinta.withAlpha(200))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Etiqueta(estado, color: colorSolicitud(estado)),
          ],
        ),
      ),
    );
  }
}
