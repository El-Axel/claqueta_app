import 'package:flutter/material.dart';
import 'modelos.dart';
import 'tema.dart';
import 'tienda.dart';
import 'util.dart';
import 'estilo.dart';

// ---------------------------------------------------------------
// WIDGETS REUTILIZABLES: las "piezas de Lego" de la identidad Pizarrón.
// Si cambias aquí un radio, un color o un tamaño, cambia en toda la app.
// ---------------------------------------------------------------

/// Navegar a otra pantalla (atajo para no repetir MaterialPageRoute).
Future<T?> ir<T>(BuildContext context, Widget pantalla) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => pantalla));

/// Tarjeta oscura con borde fino: el bloque básico de todas las pantallas.
/// - color: la tiñe (por ejemplo para un resalte).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets relleno;
  final VoidCallback? alTocar;
  final Color? color;
  final double radio;

  const Panel({
    super.key,
    required this.child,
    this.relleno = const EdgeInsets.all(16),
    this.alTocar,
    this.color,
    this.radio = 26,
  });

  @override
  Widget build(BuildContext context) {
    final tinte = color;
    final caja = Container(
      width: double.infinity,
      padding: relleno,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        color: tinte == null ? const Color(0xB8101719) : null,
        gradient: tinte == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tinte.withAlpha(120), tinte.withAlpha(50)],
              ),
        border: Border.all(color: Colors.white.withAlpha(tinte == null ? 26 : 34)),
      ),
      child: child,
    );
    if (alTocar == null) return caja;
    return GestureDetector(onTap: alTocar, child: caja);
  }
}

/// Píldora pequeña de color (estados, APIs, etc.)
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const Etiqueta(this.texto, {super.key, this.color = Paleta.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Botón de ancho completo en forma de píldora. tipo: primario (acento arena,
/// texto oscuro), secundario (oscuro con borde), arena (igual al primario) o peligro.
class BotonClaqueta extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final String tipo;
  final IconData? icono;

  const BotonClaqueta(this.texto, this.onPressed,
      {super.key, this.tipo = 'primario', this.icono});

  @override
  Widget build(BuildContext context) {
    Color letra = Paleta.suelo;
    Color? borde;
    Color? brillo;
    Color fondo = Paleta.arena;

    if (tipo == 'secundario') {
      letra = Paleta.tinta;
      fondo = Colors.white.withAlpha(12);
      borde = Colors.white.withAlpha(40);
    } else if (tipo == 'peligro') {
      letra = Paleta.terracota;
      fondo = Paleta.terracota.withAlpha(22);
      borde = Paleta.terracota.withAlpha(120);
    } else {
      brillo = Paleta.arena;
    }

    final activo = onPressed != null;
    return Opacity(
      opacity: activo ? 1 : 0.45,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: fondo,
            border: borde == null ? null : Border.all(color: borde, width: 1.2),
            boxShadow: brillo == null || !activo
                ? null
                : [BoxShadow(color: brillo.withAlpha(45), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 19, color: letra),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      texto,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15, color: letra),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título grande (Krona One) con subtítulo opcional
class Encabezado extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  const Encabezado(this.titulo, {super.key, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: estiloDisplay(tamano: 21)),
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(subtitulo!, style: estiloSuave(tamano: 13)),
          ),
      ],
    );
  }
}

/// Título de sección: texto en negrita a la izquierda y, si quieres, un enlace
/// ("Ver todo") a la derecha, como en los referentes.
class TituloSeccion extends StatelessWidget {
  final String texto;
  final String? accion;
  final VoidCallback? alAccion;

  const TituloSeccion(this.texto, {super.key, this.accion, this.alAccion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (accion != null)
            GestureDetector(
              onTap: alAccion,
              child: Text(accion!, style: estiloSuave(tamano: 13)),
            ),
        ],
      ),
    );
  }
}

/// Fila de lista: círculo con inicial, título, subtítulo y un dato a la derecha
class FilaItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String derecha;
  final String? derecha2;
  final Widget? extra;
  final VoidCallback? alTocar;

  const FilaItem({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.derecha = '',
    this.derecha2,
    this.extra,
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        relleno: const EdgeInsets.all(12),
        alTocar: alTocar,
        child: Row(
          children: [
            Ficha(inicialDe(titulo), tamano: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(subtitulo,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: estiloSuave()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (derecha.isNotEmpty)
                  Text(derecha,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                if (derecha2 != null)
                  Text(derecha2!, style: estiloSuave(tamano: 11)),
                if (extra != null) ...[const SizedBox(height: 4), extra!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de una cotización (se usa en Inicio, Cotizar y Cliente).
class FilaCot extends StatelessWidget {
  final Cotizacion c;
  final VoidCallback alTocar;

  const FilaCot(this.c, {super.key, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final cl = tienda.cliente(c.clienteId);
    return FilaItem(
      titulo: '${folio(c.n)} · ${cl.nombre}',
      subtitulo: c.proyecto,
      derecha: formatearPesos(c.total),
      extra: Etiqueta(c.estado, color: coloresEstado[c.estado] ?? Paleta.teal),
      alTocar: alTocar,
    );
  }
}

/// Fila de un trabajo agendado (Inicio, Agenda y Cliente).
class FilaTrabajo extends StatelessWidget {
  final Trabajo t;
  final VoidCallback alTocar;
  final bool conflicto;

  const FilaTrabajo(this.t, {super.key, required this.alTocar, this.conflicto = false});

  @override
  Widget build(BuildContext context) {
    final verClima = tienda.integracion('clima');
    final clima = climaDe(t.fecha);
    return FilaItem(
      titulo: t.titulo,
      subtitulo: '${fechaCorta(t.fecha)} · ${hora12(t.hora)} · ${t.lugar}',
      derecha: verClima ? '${clima.temperatura}°' : '',
      derecha2: verClima ? clima.descripcion : null,
      extra: conflicto ? const Etiqueta('Cruce de agenda', color: Paleta.terracota) : null,
      alTocar: alTocar,
    );
  }
}

/// Renglón "etiqueta ........ valor" para los detalles
class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color colorValor;

  const FilaDato(this.etiqueta, this.valor, {super.key, this.colorValor = Paleta.tinta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(etiqueta,
                style: TextStyle(color: Paleta.tinta.withAlpha(178), fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(valor,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: colorValor, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío: se muestra cuando una lista no tiene elementos.
class Vacio extends StatelessWidget {
  final String titulo;
  final String texto;

  const Vacio(this.titulo, this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white.withAlpha(36)),
      ),
      child: Column(
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(texto, textAlign: TextAlign.center, style: estiloSuave(tamano: 13)),
        ],
      ),
    );
  }
}

/// Banner de aviso (seguimiento, lluvia, cruces de agenda...).
class Aviso extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback? alTocar;

  const Aviso(this.texto,
      {super.key, this.icono = Icons.info_outline, this.color = Paleta.durazno, this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto,
                    style: TextStyle(
                        color: color, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
              ),
              if (alTocar != null) Icon(Icons.chevron_right, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de cantidad con botones − y +
class Cantidad extends StatelessWidget {
  final int valor;
  final ValueChanged<int> cambio;
  final int minimo;
  final int paso;

  const Cantidad({
    super.key,
    required this.valor,
    required this.cambio,
    this.minimo = 0,
    this.paso = 1,
  });

  Widget _boton(IconData icono, VoidCallback? accion) {
    return GestureDetector(
      onTap: accion,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(accion == null ? 8 : 18),
          border: Border.all(color: Colors.white.withAlpha(accion == null ? 24 : 70)),
        ),
        child: Icon(icono, size: 18, color: accion == null ? Paleta.tinta.withAlpha(70) : Paleta.tinta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boton(Icons.remove, valor > minimo ? () => cambio(valor - paso) : null),
        SizedBox(
          width: 34,
          child: Text('$valor',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        _boton(Icons.add, () => cambio(valor + paso)),
      ],
    );
  }
}

/// Barra de progreso (pagos).
class BarraProgreso extends StatelessWidget {
  final double valor; // de 0 a 1
  const BarraProgreso(this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: Colors.white.withAlpha(24),
        valueColor: const AlwaysStoppedAnimation<Color>(Paleta.arena),
      ),
    );
  }
}

/// Línea de progreso de una cotización: Borrador > Enviada > Aceptada/Rechazada.
class LineaEstado extends StatelessWidget {
  final String estado;
  const LineaEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final pasos = ['Borrador', 'Enviada', estado == estRechazada ? 'Rechazada' : 'Aceptada'];
    int actual = 0;
    if (estado == estEnviada) actual = 1;
    if (estado == estAceptada || estado == estRechazada) actual = 2;
    return Row(
      children: [
        for (int i = 0; i < pasos.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < pasos.length - 1 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    color: i <= actual
                        ? (pasos[i] == 'Rechazada' ? Paleta.terracota : Paleta.teal)
                        : Paleta.petroleo,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pasos[i].toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: i <= actual
                          ? (pasos[i] == 'Rechazada' ? Paleta.terracota : Paleta.teal)
                          : Paleta.tinta.withAlpha(100),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de clima (simulado; en la versión final lo da Google Weather).
class TarjetaClima extends StatelessWidget {
  final DateTime fecha;
  const TarjetaClima(this.fecha, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!tienda.integracion('clima')) {
      return Panel(
        child: Row(children: [
          const Icon(Icons.cloud_off_outlined, size: 20),
          const SizedBox(width: 10),
          Text('Clima desactivado en Ajustes', style: estiloSuave(tamano: 13)),
        ]),
      );
    }
    final c = climaDe(fecha);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.icono, color: Paleta.arena, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.temperatura}° · ${c.descripcion}',
                        style: estiloDisplay(tamano: 15)),
                    Text(fechaLarga(fecha), style: estiloSuave()),
                  ],
                ),
              ),
              const Etiqueta('Weather', color: Paleta.arena),
            ],
          ),
          const SizedBox(height: 10),
          Text('Lluvia ${c.lluvia}%   ·   Viento ${c.viento} km/h', style: estiloSuave(tamano: 13)),
          if (c.riesgoLluvia) ...[
            const SizedBox(height: 10),
            const Aviso(
              'Alta probabilidad de lluvia. Considera otra fecha o un plan B bajo techo.',
              icono: Icons.umbrella_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

/// Mapa dibujado con código (en la versión final lo da Google Maps).
class MapaSimulado extends StatelessWidget {
  final String lugar;
  final String zona;

  const MapaSimulado(this.lugar, {super.key, this.zona = ''});

  @override
  Widget build(BuildContext context) {
    if (!tienda.integracion('maps')) {
      return Panel(
        child: Row(children: [
          const Icon(Icons.location_off_outlined, size: 20),
          const SizedBox(width: 10),
          Text('Maps desactivado en Ajustes', style: estiloSuave(tamano: 13)),
        ]),
      );
    }
    int semilla = 0;
    for (final r in lugar.runes) {
      semilla = (semilla * 31 + r) % 997;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PintorMapa(semilla))),
            Positioned(
              left: 10,
              bottom: 10,
              right: 10,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Paleta.suelo.withAlpha(220),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(46)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 14, color: Paleta.terracota),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          zona.isEmpty ? lugar : '$lugar · $zona',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorMapa extends CustomPainter {
  final int semilla;
  _PintorMapa(this.semilla);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0F2227));

    // Cuadras
    final cuadra = Paint()..color = const Color(0xFF173038);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * (0.05 + i * 0.24), size.height * (0.08 + j * 0.3),
                size.width * 0.18, size.height * 0.2),
            const Radius.circular(4),
          ),
          cuadra,
        );
      }
    }

    // Calles
    final calle = Paint()
      ..color = const Color(0xFF1D3A42)
      ..strokeWidth = 2;
    for (int i = 1; i < 5; i++) {
      canvas.drawLine(Offset(size.width * i / 5, 0), Offset(size.width * i / 5, size.height), calle);
    }
    for (int j = 1; j < 3; j++) {
      canvas.drawLine(Offset(0, size.height * j / 3), Offset(size.width, size.height * j / 3), calle);
    }

    // Río
    final rio = Paint()
      ..color = const Color(0xFF1E4350)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    final ruta = Path()
      ..moveTo(-10, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.6, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.9, size.width + 10, size.height * 0.62);
    canvas.drawPath(ruta, rio);

    // Pin (su posición depende del nombre del lugar)
    final px = size.width * (0.3 + (semilla % 40) / 100);
    final py = size.height * (0.3 + ((semilla * 7) % 30) / 100);
    canvas.drawCircle(Offset(px, py), 20, Paint()..color = Paleta.terracota.withAlpha(60));
    canvas.drawCircle(Offset(px, py), 8, Paint()..color = Paleta.terracota);
    canvas.drawCircle(Offset(px, py), 3, Paint()..color = Paleta.suelo);
  }

  @override
  bool shouldRepaint(covariant _PintorMapa viejo) => viejo.semilla != semilla;
}

/// Decoración común de los campos de texto: píldora oscura con borde fino.
InputDecoration decoracionCampo(String etiqueta, {String? ayuda, Widget? icono}) {
  final OutlineInputBorder borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: BorderSide(color: Colors.white.withAlpha(34)),
  );
  return InputDecoration(
    labelText: etiqueta,
    hintText: ayuda,
    prefixIcon: icono == null
        ? null
        : IconTheme(
            data: IconThemeData(size: 20, color: Paleta.tinta.withAlpha(190)),
            child: icono,
          ),
    filled: true,
    fillColor: const Color(0xB8101719),
    border: borde,
    enabledBorder: borde,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: const BorderSide(color: Paleta.arena, width: 1.5),
    ),
  );
}

/// Campo que parece de texto pero abre un selector al tocarlo.
class CampoSelector extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final String ayuda;
  final IconData icono;
  final VoidCallback alTocar;

  const CampoSelector({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.ayuda,
    required this.icono,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: InputDecorator(
        decoration: decoracionCampo(etiqueta, icono: Icon(icono, size: 20)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valor ?? ayuda,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: valor == null ? Paleta.tinta.withAlpha(110) : Paleta.tinta),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Aviso corto abajo (SnackBar)
void mostrarAviso(BuildContext context, String mensaje) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Texto con formato de pesos
Text textoPesos(int valor, {double tamano = 20, Color color = Paleta.arena}) {
  return Text(
    formatearPesos(valor),
    style: estiloDisplay(tamano: tamano, color: color),
  );
}

/// Hoja oscura que sube desde abajo (formularios cortos, selectores).
Future<T?> hojaInferior<T>(BuildContext context, Widget Function(BuildContext) contenido) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withAlpha(160),
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121A1C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(34))),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 22 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            contenido(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Diálogo de confirmación. Devuelve true si el usuario acepta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String boton,
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Paleta.panel2.withAlpha(245),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withAlpha(50)),
      ),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(boton,
              style: TextStyle(color: peligro ? Paleta.terracota : Paleta.teal)),
        ),
      ],
    ),
  );
  return r == true;
}

/// Barra superior transparente: botón de volver circular, título centrado.
PreferredSizeWidget barra(String titulo, {List<Widget>? acciones}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
    leadingWidth: 64,
    leading: Builder(
      builder: (ctx) => Navigator.of(ctx).canPop()
          ? Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: BotonCirculo(Icons.arrow_back, () => Navigator.of(ctx).maybePop(),
                    tamano: 40),
              ),
            )
          : const SizedBox.shrink(),
    ),
    title: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
    centerTitle: true,
    actions: acciones,
  );
}

/// Contenedor estándar de pantalla con scroll y márgenes.
class Pagina extends StatelessWidget {
  final List<Widget> hijos;
  final bool conBarraInferior;

  const Pagina(this.hijos, {super.key, this.conBarraInferior = false});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, conBarraInferior ? 28 : 40),
      children: hijos,
    );
  }
}

/// Espacio vertical corto.
Widget espacio([double alto = 12]) => SizedBox(height: alto);
