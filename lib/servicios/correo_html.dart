import '../modelos.dart';
import '../util.dart';

// ---------------------------------------------------------------
// CORREO CON LA IDENTIDAD DE MARCA (HTML) para enviar cotizaciones.
//
// Concepto: la cotización como "ficha de rodaje", con el mismo lenguaje
// del portafolio (alexpino.netlify.app): fondo oscuro del set, acento
// arena, punto REC terracota, visor de cámara con esquinas, fichas tipo
// ISO / DIAFRAGMA, "Escena" y títulos que terminan en punto.
//
// Reglas de los correos HTML (distintas a una página web):
// - Se maqueta con TABLAS y estilos EN LÍNEA (style="..."), porque
//   Gmail y Outlook borran las hojas de estilo y no entienden flexbox.
// - Ancho máximo de 600 px.
// - Gmail no carga fuentes web: se pide Krona One / Figtree (Apple Mail
//   y el iPhone sí las muestran) y se dejan respaldos parecidos.
// - El logo es una imagen PNG publicada en el sitio (https); los SVG
//   no se ven en Gmail.
// - Todo texto del usuario se "escapa" (&, <, >) para no romper el HTML.
// Siempre va también una versión de texto plano.
// ---------------------------------------------------------------

// Paleta del portafolio (variables --ground, --sand, --terra, --ink...)
const _suelo = '#0B1315';
const _panel = '#111C1F';
const _petroleo = '#2A5159';
const _arena = '#F2C572';
const _terra = '#D9674E';
const _tinta = '#F4F1EA';
const _suave = '#A9ADA9'; // tinta al ~70 % sobre el fondo
const _tenue = '#6F7674'; // tinta al ~45 %
const _linea = '#22302F';
const _papel = '#ECE8DF'; // fondo exterior claro, tono cálido de la tinta

const _display = "'Krona One', 'Arial Black', 'Helvetica Neue', Arial, sans-serif";
const _cuerpo = "'Figtree', 'Helvetica Neue', Helvetica, Arial, sans-serif";

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesCortos = [
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];

String _e(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _parrafos(String s) => _e(s.trim()).replaceAll('\n', '<br>');

/// Etiqueta pequeña en mayúsculas espaciadas (como "ISO", "CAPÍTULO 01").
String _rotulo(String texto, {String color = _tenue}) =>
    '<div style="font-family:$_cuerpo;font-size:10px;font-weight:700;letter-spacing:1.8px;'
    'text-transform:uppercase;color:$color;">$texto</div>';

/// Una "ficha" de la barra de datos (como ISO 800 · DIAFRAGMA f/2.8).
String _ficha(String rotulo, String valor, {bool destacado = false}) => '''
<td valign="top" width="50%" style="width:50%;padding:12px 10px 12px 0;">
  ${_rotulo(rotulo)}
  <div style="margin-top:6px;font-family:$_cuerpo;font-size:15px;font-weight:700;color:${destacado ? _arena : _tinta};white-space:nowrap;
              border-bottom:1px dashed ${destacado ? _arena : _petroleo};padding-bottom:3px;display:inline-block;">$valor</div>
</td>''';

/// Esquina del visor de cámara (marco tipo "viewfinder").
String _esquina(String bordes) =>
    '<td width="14" height="14" style="width:14px;height:14px;line-height:0;font-size:0;$bordes">&nbsp;</td>';

/// Arma el correo HTML de una cotización.
/// - [remitente]: correo de quien envía (para el botón "Responder").
/// - [mensajePersonal]: el texto que el usuario editó en la pantalla de
///   envío; si es null se usa la presentación estándar.
String correoCotizacionHtml({
  required Cotizacion c,
  required Cliente cl,
  required Config cfg,
  required String remitente,
  String? mensajePersonal,
  bool recordatorio = false,
}) {
  final vence = c.creada.add(Duration(days: c.vigenciaDias));
  final venceCorto = '${vence.day} ${_mesesCortos[vence.month - 1]}';
  final partes = cfg.negocio.split(' - ');
  final firma = partes.first.trim();
  final oficio = partes.length > 1 ? partes.sublist(1).join(' - ').trim() : '';
  final nombreCorto = firma.split(' ').first;
  final asunto = Uri.encodeComponent('Re: Cotización ${folio(c.n)} - ${c.proyecto}');
  final hoy = DateTime.now();
  final timecode =
      '${hoy.day.toString().padLeft(2, '0')}:${hoy.month.toString().padLeft(2, '0')}:${(hoy.year % 100).toString().padLeft(2, '0')}:${c.n.toString().padLeft(2, '0')}';

  final titulo = recordatorio ? 'Seguimos en rodaje.' : '${_e(c.proyecto)}.';
  final intro = recordatorio
      ? 'Te escribo para saber si pudiste revisar la propuesta de <b style="color:$_tinta;">${_e(c.proyecto)}</b>. '
          'Si quieres, ajustamos alcance o fechas y la dejamos lista.'
      : 'Esta es la propuesta para <b style="color:$_tinta;">${_e(c.proyecto)}</b>. '
          'Plano a plano, esto es lo que incluye. El detalle completo va en el PDF adjunto.';

  // Desglose numerado, como las escenas del portafolio (01, 02, ...)
  final planos = StringBuffer();
  for (var k = 0; k < c.items.length; k++) {
    final i = c.items[k];
    planos.write('''
<tr>
  <td valign="top" width="34" style="padding:14px 0;border-top:1px solid $_linea;font-family:$_cuerpo;font-size:11px;font-weight:700;color:$_arena;letter-spacing:1px;">${(k + 1).toString().padLeft(2, '0')}</td>
  <td valign="top" style="padding:14px 8px 14px 0;border-top:1px solid $_linea;font-family:$_cuerpo;font-size:15px;color:$_tinta;">
    ${_e(i.descripcion)}${i.cantidad > 1 ? '<span style="color:$_tenue;"> &times;${i.cantidad}</span>' : ''}
  </td>
  <td valign="top" align="right" style="padding:14px 0;border-top:1px solid $_linea;font-family:$_cuerpo;font-size:15px;color:$_suave;white-space:nowrap;">${formatearPesos(i.subtotal)}</td>
</tr>''');
  }

  String linea(String k, String v) => '''
<tr>
  <td style="padding:3px 0;font-family:$_cuerpo;font-size:13px;color:$_tenue;">$k</td>
  <td align="right" style="padding:3px 0;font-family:$_cuerpo;font-size:13px;color:$_suave;white-space:nowrap;">$v</td>
</tr>''';
  final ajustes = StringBuffer();
  if (c.descuento > 0 || c.iva) ajustes.write(linea('Subtotal', formatearPesos(c.subtotal)));
  if (c.descuento > 0) {
    ajustes.write(linea('Descuento ${c.descuento}%', '&minus;${formatearPesos(c.valorDescuento)}'));
  }
  if (c.iva) ajustes.write(linea('IVA 19%', formatearPesos(c.valorIva)));

  final nota = (mensajePersonal == null || mensajePersonal.trim().isEmpty)
      ? ''
      : '''
<tr><td style="padding:0 36px 28px 36px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
    <tr><td style="border-left:2px solid $_arena;padding:2px 0 2px 16px;font-family:$_cuerpo;font-size:15px;line-height:1.6;color:$_suave;">
      ${_parrafos(mensajePersonal)}
    </td></tr>
  </table>
</td></tr>''';

  final web = cfg.web.trim().replaceFirst(RegExp(r'^https?://'), '');
  final logo = cfg.logo.trim();
  final marca = logo.isEmpty
      ? '<td width="36" height="36" style="width:36px;height:36px;background:$_arena;border-radius:10px;text-align:center;font-family:$_display;font-size:16px;color:$_suelo;">${_e(nombreCorto.isEmpty ? 'C' : nombreCorto[0].toUpperCase())}</td>'
      : '<td width="36" style="width:36px;"><img src="${_e(logo)}" width="36" height="36" alt="${_e(firma)}" style="display:block;border:0;border-radius:10px;"></td>';

  final enlaces = [
    if (cfg.telefono.isNotEmpty)
      '<a href="https://wa.me/${telefonoParaWhatsApp(cfg.telefono)}" style="color:$_suave;text-decoration:none;">WhatsApp</a>',
    if (web.isNotEmpty)
      '<a href="https://${_e(web)}" style="color:$_suave;text-decoration:none;">${_e(web)}</a>',
    if (remitente.isNotEmpty)
      '<a href="mailto:${_e(remitente)}" style="color:$_suave;text-decoration:none;">${_e(remitente)}</a>',
  ].join('<span style="color:$_tenue;"> &nbsp;·&nbsp; </span>');

  return '''
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link href="https://fonts.googleapis.com/css2?family=Krona+One&family=Figtree:wght@400;600;700&display=swap" rel="stylesheet">
<title>${folio(c.n)} · ${_e(c.proyecto)}</title>
</head>
<body style="margin:0;padding:0;background:$_papel;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">
  ${_e(c.proyecto)} · ${formatearPesos(c.total)} COP · válida hasta el ${vence.day} de ${_meses[vence.month - 1]}.
</div>
<!-- Fondo exterior claro; solo la tarjeta central es oscura (el "set") -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_papel;">
<tr><td align="center" style="padding:28px 10px 36px 10px;">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:$_suelo;border-radius:22px;">

  <!-- Barra superior: marca + REC -->
  <tr><td style="padding:28px 36px 22px 36px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
      <td valign="middle">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          $marca
          <td style="padding-left:12px;font-family:$_cuerpo;font-size:15px;font-weight:700;color:$_tinta;">${_e(firma)}</td>
        </tr></table>
      </td>
      <td valign="middle" align="right" style="font-family:$_cuerpo;font-size:11px;font-weight:700;letter-spacing:1.6px;color:$_suave;white-space:nowrap;">
        <span style="color:$_terra;font-size:13px;">&#9679;</span>&nbsp; REC &nbsp;<span style="color:$_tenue;">${folio(c.n)}</span>
      </td>
    </tr></table>
  </td></tr>

  <!-- Visor de cámara con el titular -->
  <tr><td style="padding:0 26px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
      <tr>${_esquina('border-top:2px solid $_tinta;border-left:2px solid $_tinta;')}<td></td>${_esquina('border-top:2px solid $_tinta;border-right:2px solid $_tinta;')}</tr>
      <tr><td></td><td style="padding:14px 10px 18px 10px;">
        ${_rotulo('Escena ${c.n.toString().padLeft(2, '0')} &nbsp;·&nbsp; ${recordatorio ? 'Recordatorio' : 'Propuesta'}', color: _arena)}
        <h1 style="margin:14px 0 0 0;font-family:$_display;font-weight:400;font-size:30px;line-height:1.2;color:$_tinta;">$titulo</h1>
        <p style="margin:18px 0 0 0;font-family:$_cuerpo;font-size:16px;line-height:1.6;color:$_suave;">Hola ${_e(cl.nombre)},</p>
        <p style="margin:6px 0 0 0;font-family:$_cuerpo;font-size:16px;line-height:1.6;color:$_suave;">$intro</p>
      </td><td></td></tr>
      <tr>${_esquina('border-bottom:2px solid $_tinta;border-left:2px solid $_tinta;')}<td></td>${_esquina('border-bottom:2px solid $_tinta;border-right:2px solid $_tinta;')}</tr>
    </table>
  </td></tr>

  <!-- Barra de datos tipo cámara: CLIENTE · FOLIO · VIGENCIA · TOTAL -->
  <tr><td style="padding:22px 36px 28px 36px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:$_panel;border:1px solid $_linea;border-radius:14px;">
      <tr><td style="padding:2px 18px;">
        <!-- 2 × 2 para que quepa en el celular (los correos no admiten bien media queries) -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr>
            ${_ficha('Cliente', _e(cl.nombre.length > 18 ? '${cl.nombre.substring(0, 17)}…' : cl.nombre))}
            ${_ficha('Folio', folio(c.n))}
          </tr>
          <tr>
            ${_ficha('Vigencia', venceCorto)}
            ${_ficha('Total', formatearPesos(c.total), destacado: true)}
          </tr>
        </table>
      </td></tr>
    </table>
  </td></tr>

  $nota

  <!-- Plano a plano -->
  <tr><td style="padding:0 36px;">
    ${_rotulo('Capítulo 01 &nbsp;·&nbsp; Plano a plano')}
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:10px;">$planos</table>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid $_linea;padding-top:10px;">$ajustes</table>
  </td></tr>

  <!-- Total -->
  <tr><td style="padding:22px 36px 0 36px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:2px solid $_arena;">
      <tr>
        <td valign="bottom" style="padding-top:16px;">
          ${_rotulo('Total del rodaje', color: _arena)}
          <div style="margin-top:6px;font-family:$_cuerpo;font-size:13px;color:$_tenue;">Válida hasta el ${vence.day} de ${_meses[vence.month - 1]} de ${vence.year}</div>
        </td>
        <td valign="bottom" align="right" style="padding-top:16px;font-family:$_display;font-size:22px;color:$_tinta;white-space:nowrap;">
          ${formatearPesos(c.total)}<span style="font-family:$_cuerpo;font-size:12px;font-weight:700;color:$_tenue;"> COP</span>
        </td>
      </tr>
    </table>
  </td></tr>

  <!-- Próxima escena: llamado a la acción -->
  <tr><td style="padding:40px 36px 8px 36px;">
    ${_rotulo('Capítulo 02 &nbsp;·&nbsp; Próxima escena')}
    <p style="margin:12px 0 0 0;font-family:$_display;font-size:19px;line-height:1.35;color:$_tinta;">¿La rodamos juntos?</p>
    <p style="margin:8px 0 22px 0;font-family:$_cuerpo;font-size:15px;line-height:1.6;color:$_suave;">Respóndeme este correo y ajustamos lo que haga falta.</p>
    <table role="presentation" cellpadding="0" cellspacing="0"><tr>
      <td style="background:$_arena;border-radius:999px;">
        <a href="mailto:${_e(remitente)}?subject=$asunto" style="display:inline-block;padding:14px 26px;font-family:$_cuerpo;font-size:13px;font-weight:700;letter-spacing:1.4px;text-transform:uppercase;color:$_suelo;text-decoration:none;">Responder &nbsp;&rarr;</a>
      </td>
    </tr></table>
    <p style="margin:18px 0 0 0;font-family:$_cuerpo;font-size:13px;color:$_tenue;">El PDF con el detalle completo va adjunto.</p>
  </td></tr>

  <!-- Pie con timecode -->
  <tr><td style="padding:36px 36px 32px 36px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid $_linea;">
      <tr><td style="padding-top:20px;">
        <div style="font-family:$_display;font-size:14px;color:$_tinta;">${_e(firma)}</div>
        ${oficio.isEmpty ? '' : '<div style="margin-top:4px;font-family:$_cuerpo;font-size:12px;letter-spacing:1.4px;text-transform:uppercase;color:$_tenue;">${_e(oficio)}</div>'}
        ${enlaces.isEmpty ? '' : '<div style="margin-top:12px;font-family:$_cuerpo;font-size:13px;line-height:1.7;">$enlaces</div>'}
      </td>
      <td valign="top" align="right" style="padding-top:22px;font-family:$_cuerpo;font-size:11px;font-weight:700;letter-spacing:1.5px;color:$_terra;white-space:nowrap;">
        <span style="font-size:9px;">&#9679;</span> $timecode
      </td></tr>
    </table>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>''';
}
