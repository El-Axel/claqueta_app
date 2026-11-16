import 'package:flutter/material.dart';
import '../modelos.dart';
import '../selectores.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import 'detalle_trabajo.dart';
import '../estilo.dart';

// Agendar un trabajo: la cadena completa de la app.
// dirección -> mapa -> clima -> revisión de cruces -> evento en Calendar.
class PantallaAgendar extends StatefulWidget {
  final int? cotN;
  final DateTime? fechaInicial;
  const PantallaAgendar({super.key, this.cotN, this.fechaInicial});

  @override
  State<PantallaAgendar> createState() => _PantallaAgendarState();
}

class _PantallaAgendarState extends State<PantallaAgendar> {
  int? cotN;
  int? clienteId;
  final proyecto = TextEditingController();
  final lugar = TextEditingController();
  String zona = '';
  late DateTime fecha;
  String hora = '08:00';
  bool mostrarSugerencias = false;
  bool invitarCliente = false;
  bool crearEvento = true;

  @override
  void initState() {
    super.initState();
    final hoy = soloFecha(DateTime.now());
    fecha = widget.fechaInicial != null && !widget.fechaInicial!.isBefore(hoy)
        ? widget.fechaInicial!
        : hoy.add(const Duration(days: 1));
    crearEvento = tienda.integracion('calendar');
    if (widget.cotN != null) _usarCotizacion(tienda.cotizacion(widget.cotN!));
  }

  @override
  void dispose() {
    proyecto.dispose();
    lugar.dispose();
    super.dispose();
  }

  void _usarCotizacion(Cotizacion? c) {
    if (c == null) return;
    cotN = c.n;
    clienteId = c.clienteId;
    proyecto.text = c.proyecto;
  }

  Future<void> elegirCotizacion() async {
    final libres = tienda.cotizaciones
        .where((c) => c.estado == estAceptada && tienda.trabajoDeCot(c.n) == null)
        .toList();
    final r = await hojaInferior<int>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cotización aceptada', style: estiloDisplay(tamano: 16)),
          const SizedBox(height: 4),
          Text('Solo aparecen las aceptadas que aún no tienen rodaje.',
              style: estiloSuave(tamano: 13)),
          const SizedBox(height: 14),
          if (libres.isEmpty)
            const Vacio('No hay cotizaciones libres', 'Acepta una cotización para poder agendarla.')
          else
            for (final c in libres) FilaCot(c, alTocar: () => Navigator.pop(ctx, c.n)),
          const SizedBox(height: 4),
          BotonClaqueta('Sin cotización', () => Navigator.pop(ctx, -1), tipo: 'secundario'),
        ],
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      if (r == -1) {
        cotN = null;
      } else {
        _usarCotizacion(tienda.cotizacion(r));
      }
    });
  }

  Future<void> elegirFecha() async {
    final hoy = soloFecha(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: fecha.isBefore(hoy) ? hoy : fecha,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 730)),
    );
    if (d != null && mounted) setState(() => fecha = d);
  }

  Future<void> elegirHora() async {
    final t = await showTimePicker(context: context, initialTime: timeDe(hora));
    if (t != null && mounted) setState(() => hora = horaDe(t));
  }

  Future<void> crear() async {
    if (clienteId == null) return mostrarAviso(context, 'Elige un cliente');
    if (proyecto.text.trim().isEmpty) return mostrarAviso(context, 'Escribe el nombre del trabajo');
    if (lugar.text.trim().isEmpty) return mostrarAviso(context, 'Escribe una dirección');

    if (tienda.conflictosPara(fecha, hora).isNotEmpty) {
      final seguir = await confirmar(
        context,
        titulo: 'Cruce de agenda',
        mensaje: 'Ya tienes un trabajo a esa hora o muy cerca. ¿Agendar de todas formas?',
        boton: 'Agendar igual',
      );
      if (!seguir || !mounted) return;
    }

    final cot = cotN == null ? null : tienda.cotizacion(cotN!);
    final t = Trabajo(
      id: 0,
      cotN: cotN,
      clienteId: clienteId!,
      titulo: proyecto.text.trim(),
      fecha: fecha,
      hora: hora,
      lugar: lugar.text.trim(),
      zona: zona,
      valor: cot?.total ?? 0,
      enCalendar: crearEvento,
      invitaCliente: crearEvento && invitarCliente,
    );
    final id = tienda.guardarTrabajo(t);
    if (!mounted) return;

    if (crearEvento) {
      await hojaInferior<void>(
        context,
        (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Paleta.teal, size: 48),
            const SizedBox(height: 10),
            Text('Evento creado en Calendar', style: estiloDisplay(tamano: 16)),
            const SizedBox(height: 4),
            Text('Simulado: en la versión final se crea con la API de Google Calendar.',
                textAlign: TextAlign.center, style: estiloSuave(tamano: 12)),
            const SizedBox(height: 16),
            Panel(
              color: Paleta.suelo,
              child: Column(
                children: [
                  FilaDato('Evento', t.titulo),
                  FilaDato('Fecha', '${fechaCorta(t.fecha)} · ${hora12(t.hora)}'),
                  FilaDato('Lugar', t.lugar),
                  if (tienda.integracion('clima'))
                    FilaDato('Clima', '${climaDe(t.fecha).temperatura}° ${climaDe(t.fecha).descripcion}'),
                  if (t.invitaCliente)
                    FilaDato('Invitación a', tienda.cliente(t.clienteId).correo.isEmpty
                        ? 'sin correo'
                        : tienda.cliente(t.clienteId).correo),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BotonClaqueta('Ver trabajo', () => Navigator.pop(ctx)),
          ],
        ),
      );
    }
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => DetalleTrabajo(id)));
  }

  @override
  Widget build(BuildContext context) {
    final cl = clienteId == null ? null : tienda.cliente(clienteId!);
    final cruces = tienda.conflictosPara(fecha, hora);
    final clima = climaDe(fecha);
    final necesitaPlanB = tienda.integracion('clima') && (clima.riesgoLluvia || cruces.isNotEmpty);
    final alternativas = necesitaPlanB ? tienda.alternativas(fecha, hora) : <DateTime>[];
    final q = lugar.text.trim().toLowerCase();
    final sugerencias = tienda.integracion('maps') && mostrarSugerencias && q.isNotEmpty
        ? lugaresEjemplo
            .where((l) => l.nombre.toLowerCase().contains(q) || l.zona.toLowerCase().contains(q))
            .toList()
        : <Lugar>[];

    return Lienzo(
      appBar: barra('Agendar trabajo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          CampoSelector(
            etiqueta: 'Cotización aceptada (opcional)',
            valor: cotN == null ? null : '${folio(cotN!)} · ${tienda.cotizacion(cotN!)?.proyecto ?? ''}',
            ayuda: 'Vincular una cotización',
            icono: Icons.description_outlined,
            alTocar: elegirCotizacion,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: proyecto,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('Nombre del trabajo'),
          ),
          const SizedBox(height: 14),
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CampoSelector(
                  etiqueta: 'Fecha',
                  valor: fechaCorta(fecha),
                  ayuda: '',
                  icono: Icons.calendar_today_outlined,
                  alTocar: elegirFecha,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CampoSelector(
                  etiqueta: 'Hora',
                  valor: hora12(hora),
                  ayuda: '',
                  icono: Icons.schedule,
                  alTocar: elegirHora,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: lugar,
            onChanged: (_) => setState(() {
              mostrarSugerencias = true;
              zona = '';
            }),
            decoration: decoracionCampo(
              tienda.integracion('maps') ? 'Dirección (Google Maps)' : 'Dirección',
              icono: const Icon(Icons.place_outlined, size: 20),
            ),
          ),
          if (sugerencias.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Paleta.panel2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Paleta.petroleo),
              ),
              child: Column(
                children: [
                  for (final l in sugerencias)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, size: 18, color: Paleta.teal),
                      title: Text(l.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(l.zona, style: estiloSuave()),
                      onTap: () => setState(() {
                        lugar.text = l.nombre;
                        zona = l.zona;
                        mostrarSugerencias = false;
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          MapaSimulado(lugar.text.trim().isEmpty ? 'Sin dirección' : lugar.text.trim(), zona: zona),
          const SizedBox(height: 12),
          TarjetaClima(fecha),
          if (cruces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Aviso(
              'Se cruza con: ${cruces.map((t) => '${t.titulo} (${hora12(t.hora)})').join(', ')}.',
              icono: Icons.warning_amber_rounded,
              color: Paleta.terracota,
            ),
          ],
          if (necesitaPlanB) ...[
            const TituloSeccion('Plan B: fechas sugeridas'),
            if (alternativas.isEmpty)
              const Vacio('Sin alternativas cercanas', 'No hay días libres y secos en las próximas dos semanas.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in alternativas)
                    ActionChip(
                      avatar: Icon(climaDe(d).icono, size: 16, color: Paleta.arena),
                      label: Text('${fechaCorta(d)} · ${climaDe(d).temperatura}° ${climaDe(d).descripcion}'),
                      backgroundColor: Colors.white.withAlpha(18),
                      side: BorderSide(color: Colors.white.withAlpha(50)),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      onPressed: () => setState(() => fecha = d),
                    ),
                ],
              ),
          ],
          const TituloSeccion('Calendar'),
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Crear evento en Google Calendar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: crearEvento && tienda.integracion('calendar'),
                      activeColor: Paleta.teal,
                      onChanged: tienda.integracion('calendar')
                          ? (v) => setState(() => crearEvento = v)
                          : null,
                    ),
                  ],
                ),
                if (!tienda.integracion('calendar'))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Calendar está desactivado en Ajustes.', style: estiloSuave()),
                  ),
                const Divider(color: Colors.white24, height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invitar al cliente',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            cl == null || cl.correo.isEmpty
                                ? 'Elige un cliente con correo'
                                : 'Recibe la invitación en ${cl.correo}',
                            style: estiloSuave(),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: invitarCliente && crearEvento,
                      activeColor: Paleta.teal,
                      onChanged: (cl != null && cl.correo.isNotEmpty && crearEvento)
                          ? (v) => setState(() => invitarCliente = v)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BotonClaqueta(
            crearEvento && tienda.integracion('calendar')
                ? 'Crear evento en Calendar'
                : 'Guardar trabajo',
            crear,
            icono: Icons.event_available_outlined,
          ),
          const SizedBox(height: 10),
          BotonClaqueta('Cancelar', () => Navigator.pop(context), tipo: 'secundario'),
        ],
      ),
    );
  }
}
