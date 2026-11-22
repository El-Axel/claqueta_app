import 'package:flutter/material.dart';

import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../widgets.dart';
import 'piezas_cliente.dart';

// ---------------------------------------------------------------
// NOVEDADES: avisos que el realizador le deja al cliente (cotización
// enviada, rodaje agendado, pago registrado...). Más recientes arriba.
// ---------------------------------------------------------------

class PestanaNovedadesCliente extends StatelessWidget {
  const PestanaNovedadesCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([portal, novedadesResaltadas]),
      builder: (context, _) {
        // Se ordena aquí también por si llegan desordenadas: lo nuevo arriba.
        final lista = [...portal.novedades]..sort((a, b) {
            final fa = fechaDeTexto(a['creada']) ?? DateTime(2000);
            final fb = fechaDeTexto(b['creada']) ?? DateTime(2000);
            return fb.compareTo(fa);
          });
        final nuevas = novedadesResaltadas.value;
        return ListaPortal([
          CabeceraCliente('Novedades',
              subtitulo: nuevas > 0
                  ? (nuevas == 1 ? '1 novedad nueva' : '$nuevas novedades nuevas')
                  : 'Lo último de ${nombreRealizador()}'),
          const EstadoPortal(),
          if (portal.cargando && lista.isEmpty)
            const CargandoPortal(texto: 'Buscando novedades…')
          else if (lista.isEmpty)
            const Vacio('Sin novedades',
                'Aquí te avisaremos cuando tu realizador te envíe una cotización, agende un rodaje o registre un pago.')
          else
            for (var i = 0; i < lista.length; i++) _FilaNovedad(lista[i], nueva: i < nuevas),
        ]);
      },
    );
  }
}

/// Ícono según el tipo de novedad.
IconData iconoNovedad(String? tipo) {
  switch (tipo) {
    case 'cotizacion':
      return Icons.description_outlined;
    case 'rodaje':
      return Icons.videocam_outlined;
    case 'pago':
      return Icons.payments_outlined;
    default:
      return Icons.notifications_none_rounded;
  }
}

class _FilaNovedad extends StatelessWidget {
  final Map<String, dynamic> n;
  final bool nueva;
  const _FilaNovedad(this.n, {this.nueva = false});

  @override
  Widget build(BuildContext context) {
    final fecha = fechaDeTexto(n['creada']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        relleno: const EdgeInsets.all(14),
        radio: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nueva ? Paleta.arena.withAlpha(36) : Colors.white.withAlpha(14),
              ),
              child: Icon(iconoNovedad(n['tipo'] as String?),
                  size: 19, color: nueva ? Paleta.arena : Paleta.tinta.withAlpha(200)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((n['texto'] as String?) ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: nueva ? FontWeight.w700 : FontWeight.w500)),
                  if (fecha != null) ...[
                    const SizedBox(height: 4),
                    Text(fechaRelativa(fecha), style: estiloSuave(tamano: 12)),
                  ],
                ],
              ),
            ),
            if (nueva) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Paleta.arena),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
