import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'modelos.dart';

// Paleta del Pizarrón (la misma del prototipo en Figma y del artifact)
class Paleta {
  static const Color suelo = Color(0xFF0B1315);
  static const Color panel = Color(0xFF132126);
  static const Color panel2 = Color(0xFF1A2C32);
  static const Color petroleo = Color(0xFF2A5159);
  static const Color teal = Color(0xFF2EA690);
  static const Color arena = Color(0xFFF2C572);
  static const Color durazno = Color(0xFFF29863);
  static const Color terracota = Color(0xFFD9674E);
  static const Color tinta = Color(0xFFF4F1EA);
}

// Cada estado de una cotización tiene su color
const Map<String, Color> coloresEstado = {
  estBorrador: Paleta.arena,
  estEnviada: Paleta.durazno,
  estAceptada: Paleta.teal,
  estRechazada: Paleta.terracota,
};

// Fuente de títulos (Krona One) y de texto (Figtree), como en el Pizarrón
TextStyle estiloDisplay({double tamano = 20, Color color = Paleta.tinta}) =>
    GoogleFonts.kronaOne(fontSize: tamano, color: color, height: 1.2);

TextStyle estiloSuave({double tamano = 12}) =>
    TextStyle(color: Paleta.tinta.withAlpha(153), fontSize: tamano);

ThemeData crearTema() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Paleta.suelo,
    colorScheme: const ColorScheme.dark(
      primary: Paleta.arena,
      onPrimary: Paleta.suelo,
      secondary: Paleta.teal,
      surface: Paleta.panel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.panel,
      indicatorColor: Paleta.teal.withAlpha(60),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.tinta,
      contentTextStyle: TextStyle(color: Paleta.suelo, fontWeight: FontWeight.w700),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.figtreeTextTheme(base.textTheme)
        .apply(bodyColor: Paleta.tinta, displayColor: Paleta.tinta),
  );
}
