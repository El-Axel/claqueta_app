import 'package:flutter/material.dart';
import 'tema.dart';
import 'tienda.dart';
import 'servicios/google_api.dart';
import 'servicios/nube.dart';
import 'servicios/portal_cliente.dart';
import 'pantallas/entrada.dart';
import 'pantallas/principal.dart';
import 'pantallas/cliente/principal_cliente.dart';

// main() es la puerta de entrada: carga los datos guardados y arranca la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await tienda.cargar();
  // Google (si está configurado): recupera la sesión en segundo plano.
  servicioGoogle.iniciar().catchError((_) {});
  // Nube (Supabase), si está configurada. Si falla, la app sigue local.
  try {
    await servicioNube.iniciar();
  } catch (_) {}
  // ¿Este teléfono quedó en modo cliente? Entonces abre su espacio.
  var esCliente = false;
  try {
    if (await PortalCliente.rolGuardadoEsCliente()) esCliente = await portal.restaurar();
  } catch (_) {}
  runApp(ClaquetaApp(esCliente: esCliente));
}

// Widget raíz: configura el tema y decide la primera pantalla:
// cliente → su espacio · realizador con sesión → la app · si no → entrada.
class ClaquetaApp extends StatelessWidget {
  final bool esCliente;
  const ClaquetaApp({super.key, this.esCliente = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claqueta',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      home: esCliente
          ? const PrincipalCliente()
          : tienda.sesion
              ? const PantallaPrincipal()
              : const PantallaEntrada(),
    );
  }
}
