import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'tema.dart';

// ---------------------------------------------------------------
// IDENTIDAD "VIDRIO" DEL PORTAFOLIO
// Aquí vive todo lo que da profundidad a la app:
//  - FondoVivo: manchas de luz teal / arena / terracota que flotan,
//    guías de tercios de cámara y viñeta.
//  - Lienzo: una pantalla con ese fondo detrás (reemplaza a Scaffold).
//  - DockVidrio: la barra de navegación flotante de vidrio.
//  - Visor: las esquinas del visor de cámara.
//  - ReglaTiempo y Timecode: la regla y el contador del editor de video.
//  - PintorAcanalado: el vidrio acanalado (rayas verticales).
// ---------------------------------------------------------------

/// Hora a la que se abrió la app: el timecode cuenta desde aquí.
final DateTime _apertura = DateTime.now();

class FondoVivo extends StatefulWidget {
  const FondoVivo({super.key});

  @override
  State<FondoVivo> createState() => _FondoVivoState();
}

class _FondoVivoState extends State<FondoVivo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 26));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el sistema pide menos movimiento, el fondo queda quieto.
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PintorFondo(_c),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PintorFondo extends CustomPainter {
  final Animation<double> t;
  _PintorFondo(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeInOut.transform(t.value);
    final pantalla = Offset.zero & size;
    canvas.drawRect(pantalla, Paint()..color = Paleta.suelo);

    void mancha(Alignment a, double radio, Color color) {
      final centro = Offset((a.x + 1) / 2 * size.width, (a.y + 1) / 2 * size.height);
      final r = size.longestSide * radio;
      final rect = Rect.fromCircle(center: centro, radius: r);
      canvas.drawRect(
        pantalla,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withAlpha(0)]).createShader(rect),
      );
    }

    mancha(Alignment(-0.95 + 0.55 * v, -0.85 + 0.25 * v), 0.62, Paleta.teal.withAlpha(58));
    mancha(Alignment(1.0 - 0.45 * v, -0.55 + 0.35 * v), 0.5, Paleta.arena.withAlpha(22));
    mancha(Alignment(-0.3 + 0.7 * v, 1.0 - 0.3 * v), 0.6, Paleta.terracota.withAlpha(24));
    mancha(Alignment(0.95, 0.35 + 0.3 * v), 0.45, Paleta.petroleo.withAlpha(95));

    // Guías de tercios, como el visor de una cámara
    final guia = Paint()
      ..color = Colors.white.withAlpha(5)
      ..strokeWidth = 1;
    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guia);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guia);
    }

    // Viñeta
    canvas.drawRect(
      pantalla,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withAlpha(120)],
          stops: const [0.55, 1.0],
        ).createShader(pantalla),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorFondo viejo) => false;
}

/// Pantalla con el fondo vivo detrás. Se usa en lugar de Scaffold.
class Lienzo extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  const Lienzo({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: FondoVivo()),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: extendBody,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

/// Barra de navegación flotante: solo la pestaña activa se expande en una
/// píldora teal con su nombre (referentes: salud/música). Las demás son
/// círculos de vidrio con el ícono.
class DockVidrio extends StatelessWidget {
  final int actual;
  final ValueChanged<int> alElegir;

  const DockVidrio({super.key, required this.actual, required this.alElegir});

  static const List<List<dynamic>> _items = [
    [Icons.home_outlined, Icons.home_rounded, 'Inicio'],
    [Icons.description_outlined, Icons.description, 'Cotizar'],
    [Icons.calendar_month_outlined, Icons.calendar_month, 'Agenda'],
    [Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Finanzas'],
    [Icons.people_outline, Icons.people, 'Clientes'],
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 68,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withAlpha(34), Colors.white.withAlpha(12)],
                ),
                border: Border.all(color: Colors.white.withAlpha(52)),
              ),
              child: LayoutBuilder(
                builder: (context, caja) {
                  const chico = 46.0;
                  const hueco = 4.0;
                  double grande = caja.maxWidth - (_items.length - 1) * (chico + hueco) - hueco;
                  if (grande < chico) grande = chico;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => alElegir(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            width: actual == i ? grande : chico,
                            height: 52,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              color: actual == i ? Paleta.teal : Colors.white.withAlpha(14),
                              border: Border.all(
                                color: actual == i
                                    ? Colors.transparent
                                    : Colors.white.withAlpha(40),
                              ),
                              boxShadow: actual == i
                                  ? [
                                      BoxShadow(
                                          color: Paleta.teal.withAlpha(70),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4)),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  (actual == i ? _items[i][1] : _items[i][0]) as IconData,
                                  size: 22,
                                  color: actual == i ? Paleta.suelo : Paleta.tinta.withAlpha(190),
                                ),
                                if (actual == i && grande > 80) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _items[i][2] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Paleta.suelo,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Esquinas de visor de cámara alrededor de un widget.
class Visor extends StatelessWidget {
  final Widget child;
  final Color color;
  const Visor({super.key, required this.child, this.color = Paleta.tinta});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _PintorEsquinas(color.withAlpha(190))),
          ),
        ),
      ],
    );
  }
}

class _PintorEsquinas extends CustomPainter {
  final Color color;
  _PintorEsquinas(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square;
    const l = 16.0;
    const m = 5.0; // margen hacia dentro
    final w = size.width;
    final h = size.height;
    canvas.drawPath(Path()..moveTo(m, m + l)..lineTo(m, m)..lineTo(m + l, m), p);
    canvas.drawPath(Path()..moveTo(w - m - l, m)..lineTo(w - m, m)..lineTo(w - m, m + l), p);
    canvas.drawPath(Path()..moveTo(m, h - m - l)..lineTo(m, h - m)..lineTo(m + l, h - m), p);
    canvas.drawPath(
        Path()..moveTo(w - m - l, h - m)..lineTo(w - m, h - m)..lineTo(w - m, h - m - l), p);
  }

  @override
  bool shouldRepaint(covariant _PintorEsquinas viejo) => viejo.color != color;
}

/// Regla de tiempo del editor de video, con una línea de progreso.
class ReglaTiempo extends StatelessWidget {
  final double progreso; // de 0 a 1
  const ReglaTiempo({super.key, required this.progreso});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progreso),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, valor, _) =>
            CustomPaint(painter: _PintorRegla(valor)),
      ),
    );
  }
}

class _PintorRegla extends CustomPainter {
  final double progreso;
  _PintorRegla(this.progreso);

  @override
  void paint(Canvas canvas, Size size) {
    final tick = Paint()
      ..color = Colors.white.withAlpha(46)
      ..strokeWidth = 1;
    int i = 0;
    for (double x = 0; x < size.width; x += 8, i++) {
      final alto = i % 5 == 0 ? 7.0 : 3.5;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - alto), tick);
    }
    final ancho = size.width * progreso;
    final rect = Rect.fromLTWH(0, 0, ancho, 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(colors: [Paleta.teal, Paleta.arena]).createShader(
          Rect.fromLTWH(0, 0, ancho <= 0 ? 1 : ancho, 2),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorRegla viejo) => viejo.progreso != progreso;
}

/// "● REC 00:00:46:01": contador de tiempo desde que abriste la app.
class Timecode extends StatefulWidget {
  const Timecode({super.key});

  @override
  State<Timecode> createState() => _TimecodeState();
}

class _TimecodeState extends State<Timecode> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(_apertura);
    final texto =
        '${_dos(d.inHours)}:${_dos(d.inMinutes % 60)}:${_dos(d.inSeconds % 60)}:${_dos((d.inMilliseconds % 1000) * 25 ~/ 1000)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Paleta.terracota, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('REC',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: Paleta.tinta.withAlpha(170))),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Paleta.terracota)),
      ],
    );
  }
}

/// Rayas verticales de vidrio acanalado (como el panel del portafolio).
class PintorAcanalado extends CustomPainter {
  final int opacidad;
  const PintorAcanalado({this.opacidad = 26});

  @override
  void paint(Canvas canvas, Size size) {
    const ancho = 9.0;
    for (double x = 0; x < size.width; x += ancho) {
      final r = Rect.fromLTWH(x, 0, ancho * 0.55, size.height);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withAlpha(opacidad), Colors.white.withAlpha(0)],
          ).createShader(r),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PintorAcanalado viejo) => viejo.opacidad != opacidad;
}

// ---------------------------------------------------------------
// COMPONENTES DE LOS REFERENTES
// ---------------------------------------------------------------

/// Botón circular de vidrio (flechas, ajustes, catálogo...).
class BotonCirculo extends StatelessWidget {
  final IconData icono;
  final VoidCallback alTocar;
  final double tamano;
  final Color? color;

  const BotonCirculo(this.icono, this.alTocar, {super.key, this.tamano = 42, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(16),
          border: Border.all(color: Colors.white.withAlpha(56)),
        ),
        child: Icon(icono, size: tamano * 0.46, color: color ?? Paleta.tinta),
      ),
    );
  }
}

/// Orbe de luz difuminado (como el sol naranja del referente).
class Orbe extends StatelessWidget {
  final double tamano;
  final Color color;
  const Orbe({super.key, this.tamano = 220, this.color = Paleta.durazno});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withAlpha(150), color.withAlpha(0)]),
        ),
      ),
    );
  }
}

/// Anillo de progreso con un número al centro (como el "68" de Exoplan).
class AnilloProgreso extends StatelessWidget {
  final double valor; // de 0 a 1
  final String texto;
  final double tamano;
  final Color color;

  const AnilloProgreso({
    super.key,
    required this.valor,
    required this.texto,
    this.tamano = 76,
    this.color = Paleta.teal,
  });

  @override
  Widget build(BuildContext context) {
    final v = valor.isNaN ? 0.0 : valor.clamp(0.0, 1.0);
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _PintorAnillo(v, color),
        child: Center(
          child: Text(texto, style: estiloDisplay(tamano: tamano * 0.22)),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double valor;
  final Color color;
  _PintorAnillo(this.valor, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    canvas.drawArc(
      rect,
      0,
      6.2832,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withAlpha(26),
    );
    if (valor <= 0) return;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * valor,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorAnillo viejo) =>
      viejo.valor != valor || viejo.color != color;
}

/// Avatar con anillo de rayitas (referente del perfil).
class AvatarAnillo extends StatelessWidget {
  final String inicial;
  final double tamano;
  final Color color;

  const AvatarAnillo(this.inicial, {super.key, this.tamano = 48, this.color = Paleta.teal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _PintorAnilloRayas(color),
        child: Padding(
          padding: EdgeInsets.all(tamano * 0.1),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Paleta.petroleo, Paleta.panel2],
              ),
            ),
            child: Text(
              inicial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: tamano * 0.36,
                color: Paleta.tinta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorAnilloRayas extends CustomPainter {
  final Color color;
  _PintorAnilloRayas(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    const n = 22;
    for (int i = 0; i < n; i++) {
      final a = 6.2832 * i / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, 6.2832 / n * 0.55, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAnilloRayas viejo) => viejo.color != color;
}

/// Barritas de progreso por tramos (como las del referente del entrenamiento).
class Segmentos extends StatelessWidget {
  final int total;
  final int llenos;
  final Color color;

  const Segmentos({super.key, this.total = 5, required this.llenos, this.color = Paleta.arena});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i < llenos ? color : Colors.white.withAlpha(30),
                boxShadow: i < llenos
                    ? [BoxShadow(color: color.withAlpha(90), blurRadius: 8)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tres cifras con rayita divisoria (referente del perfil).
class Estadisticas extends StatelessWidget {
  final List<List<String>> datos; // cada dato: [valor, etiqueta]
  final List<Color> colores;

  const Estadisticas(this.datos, {super.key, this.colores = const []});

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[];
    for (int i = 0; i < datos.length; i++) {
      if (i > 0) {
        hijos.add(Container(width: 1, height: 34, color: Colors.white.withAlpha(30)));
      }
      final color = i < colores.length ? colores[i] : Paleta.tinta;
      hijos.add(
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(datos[i][0], style: estiloDisplay(tamano: 20, color: color)),
              ),
              const SizedBox(height: 6),
              Text(
                datos[i][1],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: estiloSuave(tamano: 11),
              ),
            ],
          ),
        ),
      );
    }
    return Row(children: hijos);
  }
}
