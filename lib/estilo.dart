import 'dart:math';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'tema.dart';

// ---------------------------------------------------------------
// ESTILO "LIMPIO" (el del Home rediseñado, ahora en toda la app)
// - Fondo casi negro con una bruma teal arriba y un poco de grano.
// - Tarjetas suaves: blanco casi transparente, radio grande y borde
//   apenas visible (sin sombras ni degradados: menos ruido visual).
// - UN solo acento (arena) para lo importante: botón principal,
//   pestaña activa, chip elegido, cifra destacada.
// - Etiquetas de sección pequeñas en mayúsculas espaciadas.
// ---------------------------------------------------------------

// Medidas del estilo limpio en un solo sitio: si se cambian aquí,
// cambian en todas las tarjetas, filas y campos de la app.
const double radioTarjeta = 28;
const int alfaFondoSuave = 13; // relleno blanco casi transparente
const int alfaBordeSuave = 22; // borde que apenas se nota

/// Decoración de las tarjetas suaves. La usan TarjetaSuave, Panel,
/// los campos de texto y los estados vacíos para verse iguales.
/// - tinte: si se da, colorea muy poco el fondo y el borde (resaltes).
BoxDecoration decoracionSuave({double radio = radioTarjeta, Color? tinte}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radio),
    color: tinte == null ? Colors.white.withAlpha(alfaFondoSuave) : tinte.withAlpha(26),
    border: Border.all(
        color: tinte == null ? Colors.white.withAlpha(alfaBordeSuave) : tinte.withAlpha(60)),
  );
}

// Puntos de grano (se generan una sola vez; siempre iguales)
final List<Offset> _granos = () {
  final r = Random(7);
  return List<Offset>.generate(900, (_) => Offset(r.nextDouble(), r.nextDouble()));
}();

class FondoVivo extends StatelessWidget {
  const FondoVivo({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _PintorFondo(), child: SizedBox.expand()),
    );
  }
}

class _PintorFondo extends CustomPainter {
  const _PintorFondo();

  @override
  void paint(Canvas canvas, Size size) {
    final pantalla = Offset.zero & size;
    canvas.drawRect(pantalla, Paint()..color = Paleta.suelo);

    // Bruma teal que cae desde arriba
    canvas.drawRect(
      pantalla,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B4D45), Color(0xFF10302D), Paleta.suelo],
          stops: [0.0, 0.3, 0.62],
        ).createShader(pantalla),
    );

    // Un foco de luz suave arriba a la izquierda
    final foco = Rect.fromCircle(
        center: Offset(size.width * 0.15, 0), radius: size.width * 0.95);
    canvas.drawRect(
      pantalla,
      Paint()
        ..shader = RadialGradient(colors: [
          Paleta.teal.withAlpha(70),
          Paleta.teal.withAlpha(0),
        ]).createShader(foco),
    );

    // Grano fino
    final puntos = [for (final o in _granos) Offset(o.dx * size.width, o.dy * size.height)];
    canvas.drawPoints(
      PointMode.points,
      puntos,
      Paint()
        ..color = Colors.white.withAlpha(16)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorFondo viejo) => false;
}

/// Pantalla con el fondo detrás. Se usa en lugar de Scaffold.
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

/// Barra de navegación: píldora oscura flotante. La pestaña activa se expande
/// en una píldora de acento con su nombre; las demás son círculos claros.
class DockNav extends StatelessWidget {
  final int actual;
  final ValueChanged<int> alElegir;

  const DockNav({super.key, required this.actual, required this.alElegir});

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
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xF2101719),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withAlpha(30)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(120), blurRadius: 24, offset: const Offset(0, 8)),
            ],
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
                          color: actual == i ? Paleta.arena : Paleta.tinta,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon((actual == i ? _items[i][1] : _items[i][0]) as IconData,
                                size: 22, color: Paleta.suelo),
                            if (actual == i && grande > 80) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _items[i][2] as String,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
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
    );
  }
}

/// Botón circular oscuro con borde (atrás, ajustes, flechas...).
class BotonCirculo extends StatelessWidget {
  final IconData icono;
  final VoidCallback alTocar;
  final double tamano;

  const BotonCirculo(this.icono, this.alTocar, {super.key, this.tamano = 42});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        width: tamano,
        height: tamano,
        // Mismo relleno y borde que las tarjetas suaves.
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(16),
          border: Border.all(color: Colors.white.withAlpha(alfaBordeSuave)),
        ),
        child: Icon(icono, size: tamano * 0.46, color: Paleta.tinta),
      ),
    );
  }
}

/// Tarjeta hero: degradado teal -> arena con texto oscuro (como las tarjetas
/// verde-lima de los referentes).
class TarjetaHero extends StatelessWidget {
  final Widget child;
  final EdgeInsets relleno;
  final VoidCallback? alTocar;

  const TarjetaHero({
    super.key,
    required this.child,
    this.relleno = const EdgeInsets.all(22),
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      width: double.infinity,
      padding: relleno,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Paleta.teal, Paleta.arena],
        ),
        boxShadow: [
          BoxShadow(color: Paleta.teal.withAlpha(50), blurRadius: 30, offset: const Offset(0, 14)),
        ],
      ),
      child: child,
    );
    if (alTocar == null) return caja;
    return GestureDetector(onTap: alTocar, child: caja);
  }
}

/// Píldora oscura pequeña (para usar sobre la tarjeta hero o suelta).
class PildoraOscura extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final bool sobreHero;

  const PildoraOscura(this.texto, {super.key, this.icono, this.sobreHero = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: sobreHero ? Paleta.suelo.withAlpha(215) : Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(20),
        border: sobreHero ? null : Border.all(color: Colors.white.withAlpha(34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: Paleta.tinta),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Paleta.tinta, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón pequeño oscuro (como "Ask AI anything" sobre la tarjeta hero).
class BotonPildora extends StatelessWidget {
  final String texto;
  final VoidCallback alTocar;
  final IconData? icono;

  const BotonPildora(this.texto, this.alTocar, {super.key, this.icono});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Paleta.suelo,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 16, color: Paleta.arena),
              const SizedBox(width: 8),
            ],
            Text(texto,
                style: const TextStyle(
                    color: Paleta.tinta, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Cuadro de acción rápida: ícono arriba, texto abajo (Enviar / Recibir...).
class AccionRapida extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alTocar;
  final bool resaltada;

  const AccionRapida(this.icono, this.texto, this.alTocar, {super.key, this.resaltada = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xB8101719),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: resaltada ? Paleta.arena : Colors.white.withAlpha(26),
              width: resaltada ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 22, color: resaltada ? Paleta.arena : Paleta.tinta),
              const SizedBox(height: 8),
              Text(texto,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: resaltada ? Paleta.arena : Paleta.tinta.withAlpha(200))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso brillante con el resto rayado (referente "Today's Progress").
class BarraBrillante extends StatelessWidget {
  final double valor; // de 0 a 1
  const BarraBrillante(this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final double v = valor.isNaN ? 0.0 : valor.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, caja) {
        final ancho = caja.maxWidth;
        final relleno = ancho * v;
        return SizedBox(
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: const CustomPaint(painter: _PintorRayas()),
                ),
              ),
              if (relleno > 0)
                Container(
                  width: relleno < 26 ? 26 : relleno,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF8DA9C), Paleta.arena, Color(0xFFD9A94E)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Paleta.arena.withAlpha(90), blurRadius: 14),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(90),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PintorRayas extends CustomPainter {
  const _PintorRayas();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withAlpha(10));
    final p = Paint()
      ..color = Colors.white.withAlpha(26)
      ..strokeWidth = 1.4;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorRayas viejo) => false;
}

/// Cuadrito con la inicial (como los íconos de las filas de transacciones).
class Ficha extends StatelessWidget {
  final String inicial;
  final double tamano;
  final bool redonda;

  const Ficha(this.inicial, {super.key, this.tamano = 46, this.redonda = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: redonda ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: redonda ? null : BorderRadius.circular(tamano * 0.32),
        color: Colors.white.withAlpha(14),
        border: Border.all(color: Colors.white.withAlpha(alfaBordeSuave)),
      ),
      child: Text(
        inicial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: tamano * 0.38,
          color: Paleta.arena,
        ),
      ),
    );
  }
}

/// Tira de cifras con rayita divisoria.
class Estadisticas extends StatelessWidget {
  final List<List<String>> datos; // cada dato: [valor, etiqueta]
  final List<Color> colores;

  const Estadisticas(this.datos, {super.key, this.colores = const []});

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[];
    for (int i = 0; i < datos.length; i++) {
      if (i > 0) {
        hijos.add(Container(width: 1, height: 34, color: Colors.white.withAlpha(alfaBordeSuave)));
      }
      final color = i < colores.length ? colores[i] : Paleta.tinta;
      hijos.add(
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                // Igual que las cifras del Home (CifraLado): Figtree en negrita.
                child: Text(datos[i][0],
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(height: 4),
              Text(datos[i][1],
                  textAlign: TextAlign.center, maxLines: 2, style: estiloSuave(tamano: 12.5)),
            ],
          ),
        ),
      );
    }
    return Row(children: hijos);
  }
}

// ======================================================================
// Piezas del Home limpio, ahora públicas para que todas las pantallas
// las reutilicen (antes eran privadas en inicio.dart).
// ======================================================================

/// Etiqueta de sección: texto pequeño en mayúsculas y espaciado.
/// Ordena la pantalla sin gritar (no compite con el contenido).
class EtiquetaSeccion extends StatelessWidget {
  final String texto;
  const EtiquetaSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: Paleta.tinta.withAlpha(140),
        ),
      );
}

/// Tarjeta suave: el bloque principal del estilo limpio.
/// Radio grande, relleno generoso y borde casi invisible.
class TarjetaSuave extends StatelessWidget {
  final Widget child;
  final VoidCallback? alTocar;
  final EdgeInsets relleno;
  const TarjetaSuave(
      {super.key, required this.child, this.alTocar, this.relleno = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        width: double.infinity,
        padding: relleno,
        decoration: decoracionSuave(),
        child: child,
      ),
    );
  }
}

/// Renglón con ícono tenue y texto (hora, lugar, clima...).
class DatoLinea extends StatelessWidget {
  final IconData icono;
  final String texto;
  const DatoLinea(this.icono, this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icono, size: 17, color: Paleta.tinta.withAlpha(150)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Paleta.tinta.withAlpha(215))),
          ),
        ],
      );
}

/// Atajo cuadrado con ícono y nombre debajo. El principal va en arena.
class Atajo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alTocar;
  final bool principal;
  const Atajo(this.icono, this.texto, this.alTocar, {super.key, this.principal = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: principal ? Paleta.arena : Colors.white.withAlpha(14),
                border: principal ? null : Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: Icon(icono, size: 26, color: principal ? Paleta.suelo : Paleta.tinta),
            ),
            const SizedBox(height: 8),
            Text(texto, style: estiloSuave(tamano: 12.5)),
          ],
        ),
      ),
    );
  }
}

/// Cifra grande con su nombre debajo (Por cobrar / Cobrado...).
class CifraLado extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;
  const CifraLado(this.titulo, this.valor, {super.key, this.color = Paleta.tinta});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // FittedBox: si la cifra es larga, se encoge en vez de desbordar.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 3),
          Text(titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: estiloSuave(tamano: 13)),
        ],
      );
}

/// Botón píldora arena de ancho ajustado (acción dentro de una tarjeta).
class BotonArena extends StatelessWidget {
  final String texto;
  final VoidCallback alTocar;
  const BotonArena(this.texto, this.alTocar, {super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: alTocar,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: Paleta.arena,
          ),
          child: Text(texto,
              style: const TextStyle(
                  color: Paleta.suelo, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      );
}

/// Título de pantalla al estilo del saludo del Home: Figtree grande en
/// negrita (no Krona One), con subtítulo tenue debajo.
TextStyle estiloTituloPantalla() =>
    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.1, color: Paleta.tinta);
