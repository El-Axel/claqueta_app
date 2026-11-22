import 'package:flutter/material.dart';
import 'tema.dart';
import 'tienda.dart';
import 'servicios/google_api.dart';
import 'pantallas/entrada.dart';
import 'pantallas/principal.dart';

// main() es la puerta de entrada: carga los datos guardados y arranca la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await tienda.cargar();
  // Google (si está configurado): recupera la sesión en segundo plano.
  servicioGoogle.iniciar().catchError((_) {});
  runApp(const ClaquetaApp());
}

// Widget raíz: configura el tema y decide la primera pantalla
// (si ya iniciaste sesión, entra directo a la app).
class ClaquetaApp extends StatelessWidget {
  const ClaquetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claqueta',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      home: tienda.sesion ? const PantallaPrincipal() : const PantallaEntrada(),
    );
  }
}
