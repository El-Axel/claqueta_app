import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../estilo.dart';
import '../../servicios/portal_cliente.dart';
import '../../tema.dart';
import '../../widgets.dart';
import 'piezas_cliente.dart';
import 'principal_cliente.dart';

// ---------------------------------------------------------------
// ENTRADA DEL CLIENTE: escribe el código de invitación (CLQ-XXXXXX)
// que le mandó su realizador. No hay correo ni contraseña: el código
// es la llave, y el portal lo canjea contra Supabase.
// ---------------------------------------------------------------

class PantallaCodigoCliente extends StatefulWidget {
  const PantallaCodigoCliente({super.key});

  @override
  State<PantallaCodigoCliente> createState() => _PantallaCodigoClienteState();
}

class _PantallaCodigoClienteState extends State<PantallaCodigoCliente> {
  final _codigo = TextEditingController();
  bool _entrando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final texto = _codigo.text.trim();
    if (texto.isEmpty || _entrando) return;
    FocusScope.of(context).unfocus();
    setState(() => _entrando = true);
    try {
      await portal.entrarConCodigo(texto);
      if (!mounted) return;
      // Siempre se arranca en Inicio, aunque antes otro cliente
      // hubiera dejado abierta otra pestaña en este teléfono.
      pestanaCliente.value = 0;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PrincipalCliente()),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _entrando = false);
      mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra('Soy cliente'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Paleta.arena.withAlpha(30),
                border: Border.all(color: Paleta.arena.withAlpha(70)),
              ),
              child: const Icon(Icons.vpn_key_outlined, size: 34, color: Paleta.arena),
            ),
          ),
          const SizedBox(height: 22),
          Text('Entra a tu espacio',
              textAlign: TextAlign.center, style: estiloTituloPantalla()),
          const SizedBox(height: 8),
          Text(
            'Escribe tu código de invitación. Te lo envía tu realizador por WhatsApp o correo.',
            textAlign: TextAlign.center,
            style: estiloSuave(tamano: 14),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _codigo,
            enabled: !_entrando,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 10, // "CLQ-" + 6 caracteres
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3),
            inputFormatters: [
              // Solo letras, números y guion, y siempre en mayúsculas: así
              // el cliente no falla por escribir "clq-7k4m2p".
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              TextInputFormatter.withFunction(
                (viejo, nuevo) => nuevo.copyWith(text: nuevo.text.toUpperCase()),
              ),
            ],
            decoration: decoracionCampo('Código de invitación', ayuda: 'CLQ-XXXXXX')
                .copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _entrar(),
          ),
          const SizedBox(height: 18),
          BotonClaqueta(
            _entrando ? 'Entrando…' : 'Entrar',
            _entrando || _codigo.text.trim().isEmpty ? null : _entrar,
            icono: _entrando ? null : Icons.arrow_forward,
          ),
          const SizedBox(height: 22),
          TarjetaSuave(
            relleno: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: Paleta.tinta.withAlpha(150)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Solo verás tus cotizaciones, tus rodajes y los avisos de tu realizador. '
                    'No necesitas crear una cuenta.',
                    style: estiloSuave(tamano: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
