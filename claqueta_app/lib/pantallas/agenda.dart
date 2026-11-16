import 'package:flutter/material.dart';
import '../modelos.dart';
import '../tema.dart';
import '../tienda.dart';
import '../util.dart';
import '../widgets.dart';
import '../estilo.dart';
import 'agendar_trabajo.dart';
import 'detalle_trabajo.dart';

// Agenda: tira semanal con puntos y, debajo, la línea de tiempo del día
// (referente Exoplan): una línea vertical con burbujas de hora y bloques de
// color por trabajo. Entre trabajos se muestra el margen de descanso.
class PestanaAgenda extends StatefulWidget {
  const PestanaAgenda({super.key});

  @override
  State<PestanaAgenda> createState() => _PestanaAgendaState();
}

class _PestanaAgendaState extends State<PestanaAgenda> {
  DateTime seleccionado = soloFecha(DateTime.now());
  int semana = 0; // 0 = esta semana, 1 = la siguiente, -1 = la anterior

  static const List<Color> _colores = [
    Paleta.teal,
    Paleta.arena,
    Paleta.durazno,
    Paleta.petroleo,
  ];

  String _margen(Trabajo a, Trabajo b) {
    final m = minutos(b.hora) - minutos(a.hora);
    if (m < 60) return '$m min entre inicios';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h h entre inicios' : '$h h $r min entre inicios';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tienda,
      builder: (context, _) {
        final hoy = soloFecha(DateTime.now());
        final base = hoy.add(Duration(days: semana * 7));
        final lunes = base.subtract(Duration(days: base.weekday - 1));
        final dias = [for (int i = 0; i < 7; i++) lunes.add(Duration(days: i))];
        final delDia = tienda.trabajosDelDia(seleccionado);
        final cruces = tienda.idsEnConflicto();
        final proximos =
            tienda.proximos.where((t) => !mismoDia(t.fecha, seleccionado)).toList();
        final mitad = dias[3];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
          children: [
            Row(
              children: [
                Expanded(
                  child: Encabezado('Agenda',
                      subtitulo: '${mesesLargos[mitad.month - 1]} ${mitad.year}'),
                ),
                BotonCirculo(Icons.chevron_left, () => setState(() => semana--), tamano: 40),
                const SizedBox(width: 8),
                BotonCirculo(Icons.chevron_right, () => setState(() => semana++), tamano: 40),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final d in dias)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _DiaCelda(
                        dia: d,
                        seleccionado: mismoDia(d, seleccionado),
                        esHoy: mismoDia(d, hoy),
                        cantidad: tienda.trabajos.where((t) => mismoDia(t.fecha, d)).length,
                        alTocar: () => setState(() => seleccionado = d),
                      ),
                    ),
                  ),
              ],
            ),
            TituloSeccion(
              '${fechaCorta(seleccionado)}${tienda.integracion('clima') ? ' · ${climaDe(seleccionado).temperatura}° ${climaDe(seleccionado).descripcion}' : ''}',
            ),
            if (delDia.isEmpty)
              const Vacio('Día libre', 'No hay trabajos agendados para esta fecha.')
            else
              Stack(
                children: [
                  // La línea vertical que une todas las burbujas de hora
                  Positioned(
                    left: 29,
                    top: 14,
                    bottom: 14,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: Colors.white.withAlpha(30),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (int i = 0; i < delDia.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 68, top: 4, bottom: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('· ${_margen(delDia[i - 1], delDia[i])}',
                                  style: estiloSuave(tamano: 10)),
                            ),
                          ),
                        _BloqueTrabajo(
                          t: delDia[i],
                          color: cruces.contains(delDia[i].id)
                              ? Paleta.terracota
                              : _colores[i % _colores.length],
                          conflicto: cruces.contains(delDia[i].id),
                          alTocar: () => ir(context, DetalleTrabajo(delDia[i].id)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            if (proximos.isNotEmpty) ...[
              const TituloSeccion('Próximos trabajos'),
              for (final t in proximos)
                FilaTrabajo(t,
                    conflicto: cruces.contains(t.id),
                    alTocar: () => ir(context, DetalleTrabajo(t.id))),
            ],
            const SizedBox(height: 14),
            BotonClaqueta(
                'Agendar trabajo', () => ir(context, PantallaAgendar(fechaInicial: seleccionado))),
          ],
        );
      },
    );
  }
}

class _BloqueTrabajo extends StatelessWidget {
  final Trabajo t;
  final Color color;
  final bool conflicto;
  final VoidCallback alTocar;

  const _BloqueTrabajo({
    required this.t,
    required this.color,
    required this.conflicto,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final partes = hora12(t.hora).split(' ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Burbuja de hora sobre la línea
        SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: Paleta.suelo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(150)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(partes[0],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    Text(partes.length > 1 ? partes[1] : '',
                        style: TextStyle(fontSize: 9, color: Paleta.tinta.withAlpha(150))),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Panel(
              alTocar: alTocar,
              relleno: const EdgeInsets.fromLTRB(0, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                      if (tienda.integracion('clima'))
                        Text('${climaDe(t.fecha).temperatura}°',
                            style: estiloDisplay(tamano: 14, color: Paleta.arena)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tienda.cliente(t.clienteId).nombre, style: estiloSuave(tamano: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: Paleta.tinta.withAlpha(170)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(t.lugar,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: estiloSuave(tamano: 12)),
                      ),
                    ],
                  ),
                  if (conflicto) ...[
                    const SizedBox(height: 8),
                    const Etiqueta('Cruce de agenda', color: Paleta.terracota),
                  ],
                ],
              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaCelda extends StatelessWidget {
  final DateTime dia;
  final bool seleccionado;
  final bool esHoy;
  final int cantidad;
  final VoidCallback alTocar;

  const _DiaCelda({
    required this.dia,
    required this.seleccionado,
    required this.esHoy,
    required this.cantidad,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? Paleta.arena : const Color(0xB8101719),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionado
                ? Colors.transparent
                : (esHoy ? Paleta.arena.withAlpha(150) : Colors.white.withAlpha(24)),
          ),
          boxShadow: seleccionado
              ? [BoxShadow(color: Paleta.arena.withAlpha(60), blurRadius: 14)]
              : null,
        ),
        child: Column(
          children: [
            Container(
              height: 5,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < (cantidad > 3 ? 3 : cantidad); i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: seleccionado ? Paleta.suelo : Paleta.arena,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(nombreDia(dia).substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: seleccionado ? Paleta.suelo.withAlpha(170) : Paleta.tinta.withAlpha(150))),
            const SizedBox(height: 4),
            Text('${dia.day}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: seleccionado ? Paleta.suelo : Paleta.tinta.withAlpha(220))),
          ],
        ),
      ),
    );
  }
}
