import 'package:flutter/material.dart';

import '../estilo.dart';
import '../selectores.dart';
import '../servicios/nube.dart';
import '../tema.dart';
import '../tienda.dart';
import '../widgets.dart';
import 'principal.dart';

// ---------------------------------------------------------------
// CUENTA DEL REALIZADOR: crear cuenta o entrar con correo y contraseña.
//
// ¿Dónde se guardan? En Supabase Auth (el mismo proyecto de la nube):
// - El correo queda en la tabla interna auth.users.
// - La contraseña se guarda CIFRADA (hash bcrypt): ni la app ni nosotros
//   podemos leerla.
// - La app solo guarda la sesión (un token que se renueva solo), por eso
//   no hay que volver a escribir la contraseña hasta "Cerrar sesión".
//
// Google va aparte y es opcional: se conecta después, desde Ajustes, solo
// para enviar por Gmail y agendar en Calendar.
// ---------------------------------------------------------------

class PantallaCuenta extends StatefulWidget {
  /// true = crear cuenta nueva; false = ya tengo cuenta.
  final bool crear;
  const PantallaCuenta({super.key, required this.crear});

  @override
  State<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends State<PantallaCuenta> {
  late bool _crear = widget.crear;
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ver = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  /// Revisa el formulario antes de ir a Supabase. Devuelve el error o null.
  String? _validar() {
    final correo = _correo.text.trim();
    if (_crear && _nombre.text.trim().isEmpty) return 'Escribe tu nombre o el de tu negocio';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) return 'Escribe un correo válido';
    if (_clave.text.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final error = _validar();
    if (error != null) {
      mostrarAviso(context, error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);
    try {
      if (_crear) {
        await servicioNube.crearCuenta(_correo.text, _clave.text, nombre: _nombre.text);
      } else {
        await servicioNube.entrarConCorreo(_correo.text, _clave.text);
      }
      if (!mounted) return;
      // Trae (o sube) los datos de esta cuenta.
      await sincronizarCuenta(context);
      // Cuenta nueva: el nombre queda como nombre del negocio.
      if (_crear && tienda.config.negocio == 'Mi negocio') {
        tienda.config.negocio = _nombre.text.trim();
        tienda.guardarConfig();
      }
      if (!mounted) return;
      tienda.iniciarSesion();
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaPrincipal()), (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lienzo(
      appBar: barra(_crear ? 'Crear cuenta' : 'Entrar'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        children: [
          Text(_crear ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
              style: estiloTituloPantalla()),
          const SizedBox(height: 8),
          Text(
            _crear
                ? 'Con tu cuenta, tus clientes, cotizaciones y agenda quedan guardados en la nube.'
                : 'Entra con el correo y la contraseña de tu cuenta de Claqueta.',
            style: estiloSuave(tamano: 14),
          ),
          const SizedBox(height: 24),
          if (_crear) ...[
            TextField(
              controller: _nombre,
              enabled: !_enviando,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: decoracionCampo('Tu nombre o tu negocio',
                  icono: const Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _correo,
            enabled: !_enviando,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: decoracionCampo('Correo', icono: const Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clave,
            enabled: !_enviando,
            obscureText: !_ver,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            autofillHints: [_crear ? AutofillHints.newPassword : AutofillHints.password],
            onSubmitted: (_) => _enviar(),
            decoration: decoracionCampo('Contraseña',
                    ayuda: _crear ? 'Mínimo 6 caracteres' : null,
                    icono: const Icon(Icons.lock_outline))
                .copyWith(
              suffixIcon: IconButton(
                tooltip: _ver ? 'Ocultar contraseña' : 'Ver contraseña',
                icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _ver = !_ver),
              ),
            ),
          ),
          const SizedBox(height: 20),
          BotonClaqueta(
            _enviando ? 'Un momento…' : (_crear ? 'Crear cuenta' : 'Entrar'),
            _enviando ? null : _enviar,
            icono: _enviando ? null : Icons.arrow_forward,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _enviando ? null : () => setState(() => _crear = !_crear),
              child: Text(
                _crear ? '¿Ya tienes cuenta? Entra aquí' : '¿No tienes cuenta? Créala aquí',
                style: const TextStyle(color: Paleta.arena),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TarjetaSuave(
            relleno: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: Paleta.arena, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu contraseña se guarda cifrada en el servidor: nadie puede leerla, ni '
                    'siquiera la app. Gmail y Calendar se conectan después, en Ajustes.',
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
