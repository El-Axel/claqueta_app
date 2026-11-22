import 'dart:async';

import 'package:flutter/material.dart';
import '../modelos.dart';
import '../servicios/google_api.dart';
import '../servicios/lugares_api.dart';
import '../servicios/ubicacion.dart';
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
  double? lat;
  double? lon;
  late DateTime fecha;
  String hora = '08:00';
  bool mostrarSugerencias = false;
  // Búsqueda de direcciones en OpenStreetMap
  Timer? _espera;
  bool buscando = false;
  String? errorBusqueda;
  List<Lugar> resultados = [];
  bool invitarCliente = false;
  bool crearEvento = true;
  int? idGuardado; // id del trabajo una vez guardado

  @override
  void initState() {
    super.initState();
    final hoy = soloFecha(DateTime.now());
    fecha = widget.fechaInicial != null && !widget.fechaInicial!.isBefore(hoy)
        ? widget.fechaInicial!
        : hoy.add(const Duration(days: 1));
    crearEvento = tienda.integracion('calendar');
    if (widget.cotN != null) _usarCotizacion(tienda.cotizacion(widget.cotN!));
    // Al abrir la pantalla se detecta dónde estás (pide permiso la
    // primera vez). Se hace después del primer cuadro para poder
    // mostrar el diálogo de permiso de Android.
    if (tienda.integracion('maps')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => detectarUbicacion());
    }
  }

  // Estado de la detección: null = buscando, true = ok, false = falló.
  bool? ubicacionOk;
  String? motivoUbicacion;

  /// Detecta la ubicación actual y la usa como zona de búsqueda.
  /// Si falla, no interrumpe: deja la opción de reintentar o elegir ciudad.
  Future<void> detectarUbicacion() async {
    setState(() => ubicacionOk = null);
    try {
      await usarMiUbicacion();
      if (!mounted) return;
      setState(() => ubicacionOk = true);
      if (lugar.text.trim().length >= 3) alEscribirLugar(lugar.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ubicacionOk = false;
        motivoUbicacion = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    proyecto.dispose();
    lugar.dispose();
    super.dispose();
  }

  /// Respaldo si no hay ubicación: escribir la ciudad a mano.
  Future<void> cambiarCiudad() async {
    await elegirCiudad(context, motivo: motivoUbicacion);
    if (!mounted) return;
    setState(() {});
    if (lugar.text.trim().length >= 3) alEscribirLugar(lugar.text);
  }

  /// Se llama al escribir la dirección. Espera 700 ms sin teclear antes
  /// de consultar OpenStreetMap (regla de uso: 1 consulta por segundo).
  void alEscribirLugar(String texto) {
    setState(() {
      mostrarSugerencias = true;
      zona = '';
      lat = null;
      lon = null;
      errorBusqueda = null;
    });
    _espera?.cancel();
    if (!tienda.integracion('maps') || texto.trim().length < 3) {
      setState(() => resultados = []);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 700), () async {
      setState(() => buscando = true);
      try {
        final r = await buscarLugares(texto, cerca: (tienda.config.lat, tienda.config.lon));
        if (!mounted || lugar.text != texto) return;
        setState(() => resultados = r);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          resultados = [];
          errorBusqueda = 'Sin conexión con el mapa: puedes escribir la dirección igual.';
        });
      } finally {
        if (mounted) setState(() => buscando = false);
      }
    });
  }

  void elegirLugar(Lugar l) {
    _espera?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      lugar.text = l.nombre;
      zona = l.zona;
      lat = l.lat;
      lon = l.lon;
      mostrarSugerencias = false;
      resultados = [];
    });
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
      lat: lat,
      lon: lon,
      valor: cot?.total ?? 0,
      enCalendar: crearEvento,
      invitaCliente: crearEvento && invitarCliente,
    );
    final id = tienda.guardarTrabajo(t);
    // Ya guardado: que no aparezca como "cruce" consigo mismo.
    setState(() => idGuardado = id);
    if (!mounted) return;

    // Evento REAL en Google Calendar (si hay sesión de Google).
    String? errorCalendar;
    var eventoReal = false;
    if (crearEvento && servicioGoogle.conectado) {
      try {
        final invitado = t.invitaCliente ? tienda.cliente(t.clienteId).correo : null;
        final (eventoId, _) = await servicioGoogle.crearEvento(t, invitado: invitado);
        final guardado = tienda.trabajo(id);
        if (guardado != null) {
          guardado.eventoId = eventoId;
          tienda.guardarTrabajo(guardado);
        }
        eventoReal = true;
      } catch (e) {
        errorCalendar = e.toString().replaceFirst('Exception: ', '');
        final guardado = tienda.trabajo(id);
        if (guardado != null) {
          guardado.enCalendar = false;
          tienda.guardarTrabajo(guardado);
        }
      }
      if (!mounted) return;
    }

    if (errorCalendar != null) {
      mostrarAviso(context, 'Trabajo guardado, pero Calendar falló: $errorCalendar');
    } else if (crearEvento) {
      await hojaInferior<void>(
        context,
        (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Paleta.arena, size: 48), // acento único
            const SizedBox(height: 10),
            Text('Evento creado en Calendar', style: estiloDisplay(tamano: 16)),
            const SizedBox(height: 4),
            Text(
                eventoReal
                    ? 'Creado en el calendario de ${servicioGoogle.correo}.'
                    : 'Modo demostración: inicia sesión con Google para crearlo de verdad.',
                textAlign: TextAlign.center,
                style: estiloSuave(tamano: 12)),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                children: [
                  FilaDato('Evento', t.titulo),
                  FilaDato('Fecha', '${fechaCorta(t.fecha)} · ${hora12(t.hora)}'),
                  FilaDato('Lugar', t.lugar),
                  if (tienda.integracion('clima'))
                    FilaDato('Clima', '${climaTrabajo(t).temperatura}° ${climaTrabajo(t).descripcion}'),
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
    final cruces = tienda.conflictosPara(fecha, hora, ignorarId: idGuardado);
    final clima = climaDe(fecha, lat: lat, lon: lon);
    final necesitaPlanB = tienda.integracion('clima') && (clima.riesgoLluvia || cruces.isNotEmpty);
    final alternativas = necesitaPlanB ? tienda.alternativas(fecha, hora) : <DateTime>[];
    final q = lugar.text.trim().toLowerCase();
    // Resultados reales de OpenStreetMap; si aún no hay, los lugares de
    // ejemplo que coinciden (funcionan sin conexión).
    final sugerencias = tienda.integracion('maps') && mostrarSugerencias && q.isNotEmpty
        ? (resultados.isNotEmpty
            ? resultados
            : lugaresEjemplo
                .where((l) =>
                    l.nombre.toLowerCase().contains(q) || l.zona.toLowerCase().contains(q))
                .toList())
        : <Lugar>[];

    return Lienzo(
      appBar: barra('Agendar trabajo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
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
            onChanged: alEscribirLugar,
            decoration: decoracionCampo(
              tienda.integracion('maps') ? 'Dirección o lugar (mapa)' : 'Dirección',
              icono: buscando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.place_outlined, size: 20),
            ),
          ),
          if (tienda.integracion('maps'))
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  Icon(
                    ubicacionOk == true ? Icons.my_location : Icons.location_searching,
                    size: 14,
                    color: ubicacionOk == true ? Paleta.arena : Paleta.tinta.withAlpha(140),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ubicacionOk == null
                          ? 'Detectando tu ubicación…'
                          : ubicacionOk == true
                              ? 'Cerca de ti: ${tienda.config.ciudad}'
                              : tienda.config.ciudad.isEmpty
                                  ? 'Sin ubicación: buscando en toda Colombia'
                                  : 'Sin ubicación: usando ${tienda.config.ciudad}',
                      overflow: TextOverflow.ellipsis,
                      style: estiloSuave(tamano: 12),
                    ),
                  ),
                  // Si falló: reintentar o escribir la ciudad a mano.
                  if (ubicacionOk == false) ...[
                    TextButton(onPressed: detectarUbicacion, child: const Text('Reintentar')),
                    TextButton(onPressed: cambiarCiudad, child: const Text('Ciudad')),
                  ],
                ],
              ),
            ),
          if (errorBusqueda != null) ...[
            const SizedBox(height: 6),
            Text(errorBusqueda!, style: estiloSuave(tamano: 12)),
          ],
          if (sugerencias.isNotEmpty)
            Container(
              // Lista de sugerencias como tarjeta suave (antes caja petróleo
              // con borde duro). Se recorta para que los toques respeten el radio.
              margin: const EdgeInsets.only(top: 8),
              clipBehavior: Clip.antiAlias,
              decoration: decoracionSuave(radio: 20),
              // Material transparente: los ListTile necesitan un Material
              // como padre para pintar el efecto de toque sobre la tarjeta.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                children: [
                  for (final l in sugerencias)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18, color: Paleta.arena),
                      title: Text(l.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          l.lat == null
                              ? l.zona
                              : '${l.zona} · a ${textoDistancia(distanciaKm((tienda.config.lat, tienda.config.lon), (l.lat!, l.lon!)))}',
                          style: estiloSuave()),
                      onTap: () => elegirLugar(l),
                    ),
                ],
              ),
              ),
            ),
          const SizedBox(height: 14),
          MapaLugar(lugar.text.trim().isEmpty ? 'Sin dirección' : lugar.text.trim(),
              zona: zona, lat: lat, lon: lon),
          const SizedBox(height: 12),
          TarjetaClima(fecha, lat: lat, lon: lon),
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
                      avatar: Icon(climaDe(d, lat: lat, lon: lon).icono,
                          size: 16, color: Paleta.arena),
                      label: Text(
                          '${fechaCorta(d)} · ${climaDe(d, lat: lat, lon: lon).temperatura}° ${climaDe(d, lat: lat, lon: lon).descripcion}'),
                      // Chip con el vidrio suave de las tarjetas.
                      backgroundColor: Colors.white.withAlpha(13),
                      side: BorderSide(color: Colors.white.withAlpha(22)),
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
                    // El color del interruptor lo pone el tema (arena).
                    Switch(
                      value: crearEvento && tienda.integracion('calendar'),
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
                const Divider(height: 22),
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
