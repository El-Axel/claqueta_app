// ---------------------------------------------------------------
// MODELOS: las "cosas" que maneja la app. Cada clase sabe convertirse
// a JSON (toJson) y reconstruirse desde JSON (fromJson); así se guardan
// en el teléfono y se exportan en la copia de seguridad.
// ---------------------------------------------------------------

const String estBorrador = 'Borrador';
const String estEnviada = 'Enviada';
const String estAceptada = 'Aceptada';
const String estRechazada = 'Rechazada';
const List<String> estados = [estBorrador, estEnviada, estAceptada, estRechazada];

class Cliente {
  int id;
  String nombre;
  String correo;
  String telefono;
  String notas;

  Cliente({
    required this.id,
    required this.nombre,
    this.correo = '',
    this.telefono = '',
    this.notas = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'notas': notas,
      };

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        correo: (j['correo'] ?? '') as String,
        telefono: (j['telefono'] ?? '') as String,
        notas: (j['notas'] ?? '') as String,
      );
}

/// Un servicio del catálogo con su precio por unidad
/// (por ejemplo: "Edición de video", unidad "video", $500.000).
class Servicio {
  int id;
  String nombre;
  String unidad;
  int precio;

  Servicio({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.precio,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'nombre': nombre, 'unidad': unidad, 'precio': precio};

  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        unidad: (j['unidad'] ?? 'servicio') as String,
        precio: j['precio'] as int,
      );
}

/// Un paquete: conjunto de servicios (id del servicio -> cantidad)
/// con un descuento opcional en porcentaje.
class Paquete {
  int id;
  String nombre;
  String descripcion;
  Map<int, int> items;
  int descuento;

  Paquete({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.items,
    this.descuento = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'items': items.map((k, v) => MapEntry(k.toString(), v)),
        'descuento': descuento,
      };

  factory Paquete.fromJson(Map<String, dynamic> j) => Paquete(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
        descripcion: (j['descripcion'] ?? '') as String,
        items: (j['items'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        descuento: (j['descuento'] ?? 0) as int,
      );
}

/// Una línea de una cotización. Guarda copia del nombre y del precio
/// para que cambiar el catálogo después no altere cotizaciones viejas.
class ItemCot {
  String descripcion;
  String unidad;
  int precio;
  int cantidad;

  ItemCot({
    required this.descripcion,
    this.unidad = 'servicio',
    required this.precio,
    required this.cantidad,
  });

  int get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
        'descripcion': descripcion,
        'unidad': unidad,
        'precio': precio,
        'cantidad': cantidad,
      };

  factory ItemCot.fromJson(Map<String, dynamic> j) => ItemCot(
        descripcion: j['descripcion'] as String,
        unidad: (j['unidad'] ?? 'servicio') as String,
        precio: j['precio'] as int,
        cantidad: j['cantidad'] as int,
      );
}

class Cotizacion {
  int n;
  int clienteId;
  String proyecto;
  String estado;
  List<ItemCot> items;
  int descuento; // porcentaje
  bool iva;
  String notas;
  DateTime creada;
  DateTime? enviada;
  int vigenciaDias;

  Cotizacion({
    required this.n,
    required this.clienteId,
    required this.proyecto,
    this.estado = estBorrador,
    required this.items,
    this.descuento = 0,
    this.iva = false,
    this.notas = '',
    required this.creada,
    this.enviada,
    this.vigenciaDias = 15,
  });

  // Los cálculos viven aquí: así hay UNA sola forma de calcular el total
  // y la pantalla, el PDF y las finanzas siempre coinciden.
  int get subtotal => items.fold<int>(0, (a, i) => a + i.subtotal);
  int get valorDescuento => (subtotal * descuento / 100).round();
  int get base => subtotal - valorDescuento;
  int get valorIva => iva ? (base * 0.19).round() : 0;
  int get total => base + valorIva;

  /// Fecha hasta la que vale el precio (cuenta desde que se envió).
  DateTime get vence => (enviada ?? creada).add(Duration(days: vigenciaDias));

  Map<String, dynamic> toJson() => {
        'n': n,
        'clienteId': clienteId,
        'proyecto': proyecto,
        'estado': estado,
        'items': items.map((i) => i.toJson()).toList(),
        'descuento': descuento,
        'iva': iva,
        'notas': notas,
        'creada': creada.toIso8601String(),
        'enviada': enviada?.toIso8601String(),
        'vigenciaDias': vigenciaDias,
      };

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        n: j['n'] as int,
        clienteId: j['clienteId'] as int,
        proyecto: j['proyecto'] as String,
        estado: (j['estado'] ?? estBorrador) as String,
        items: (j['items'] as List)
            .map((e) => ItemCot.fromJson(e as Map<String, dynamic>))
            .toList(),
        descuento: (j['descuento'] ?? 0) as int,
        iva: (j['iva'] ?? false) as bool,
        notas: (j['notas'] ?? '') as String,
        creada: DateTime.parse(j['creada'] as String),
        enviada: j['enviada'] == null ? null : DateTime.parse(j['enviada'] as String),
        vigenciaDias: (j['vigenciaDias'] ?? 15) as int,
      );
}

class Pago {
  String tipo;
  int monto;
  String metodo;
  DateTime fecha;

  Pago({
    required this.tipo,
    required this.monto,
    required this.metodo,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'monto': monto,
        'metodo': metodo,
        'fecha': fecha.toIso8601String(),
      };

  factory Pago.fromJson(Map<String, dynamic> j) => Pago(
        tipo: j['tipo'] as String,
        monto: j['monto'] as int,
        metodo: (j['metodo'] ?? 'Transferencia') as String,
        fecha: DateTime.parse(j['fecha'] as String),
      );
}

class Trabajo {
  int id;
  int? cotN;
  int clienteId;
  String titulo;
  DateTime fecha;
  String hora; // "14:00"
  String lugar;
  String zona;
  double? lat; // coordenadas del lugar (OpenStreetMap)
  double? lon;
  int valor;
  List<Pago> pagos;
  bool enCalendar;
  bool invitaCliente;
  String? eventoId; // id del evento creado en Google Calendar

  Trabajo({
    required this.id,
    this.cotN,
    required this.clienteId,
    required this.titulo,
    required this.fecha,
    required this.hora,
    required this.lugar,
    this.zona = '',
    this.lat,
    this.lon,
    required this.valor,
    List<Pago>? pagos,
    this.enCalendar = false,
    this.invitaCliente = false,
    this.eventoId,
  }) : pagos = pagos ?? [];

  int get pagado => pagos.fold<int>(0, (a, p) => a + p.monto);
  int get pendiente => valor - pagado > 0 ? valor - pagado : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cotN': cotN,
        'clienteId': clienteId,
        'titulo': titulo,
        'fecha': fecha.toIso8601String(),
        'hora': hora,
        'lugar': lugar,
        'zona': zona,
        'lat': lat,
        'lon': lon,
        'valor': valor,
        'pagos': pagos.map((p) => p.toJson()).toList(),
        'enCalendar': enCalendar,
        'invitaCliente': invitaCliente,
        'eventoId': eventoId,
      };

  factory Trabajo.fromJson(Map<String, dynamic> j) => Trabajo(
        id: j['id'] as int,
        cotN: j['cotN'] as int?,
        clienteId: j['clienteId'] as int,
        titulo: j['titulo'] as String,
        fecha: DateTime.parse(j['fecha'] as String),
        hora: (j['hora'] ?? '08:00') as String,
        lugar: (j['lugar'] ?? '') as String,
        zona: (j['zona'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        eventoId: j['eventoId'] as String?,
        valor: (j['valor'] ?? 0) as int,
        pagos: ((j['pagos'] ?? []) as List)
            .map((e) => Pago.fromJson(e as Map<String, dynamic>))
            .toList(),
        enCalendar: (j['enCalendar'] ?? false) as bool,
        invitaCliente: (j['invitaCliente'] ?? false) as bool,
      );
}

class Config {
  String negocio;
  String telefono;
  bool iva;
  int vigenciaDias;
  int recordatorioDias;
  Map<String, bool> integraciones;
  // Zona base: prioriza lugares cercanos al buscar y da el clima del
  // Inicio. Sale de "Usar mi ubicación" o se deja la de por defecto.
  String ciudad;
  double lat;
  double lon;
  // Identidad en los correos: sitio web y logo (imagen PNG pública).
  String web;
  String logo;

  Config({
    this.web = 'alexpino.netlify.app',
    this.logo = 'https://alexpino.netlify.app/assets/img/apple-touch-icon.png',
    this.ciudad = '', // vacío = aún sin zona (se usan las coordenadas de Medellín)
    this.lat = 6.2476,
    this.lon = -75.5658,
    this.negocio = 'Alexander Pino - Realizador audiovisual',
    this.telefono = '',
    this.iva = false,
    this.vigenciaDias = 15,
    this.recordatorioDias = 5,
    Map<String, bool>? integraciones,
  }) : integraciones = integraciones ??
            {'maps': true, 'clima': true, 'calendar': true, 'gmail': true};

  Map<String, dynamic> toJson() => {
        'negocio': negocio,
        'telefono': telefono,
        'iva': iva,
        'vigenciaDias': vigenciaDias,
        'recordatorioDias': recordatorioDias,
        'integraciones': integraciones,
        'ciudad': ciudad,
        'lat': lat,
        'lon': lon,
        'web': web,
        'logo': logo,
      };

  factory Config.fromJson(Map<String, dynamic> j) => Config(
        negocio: (j['negocio'] ?? 'Mi negocio') as String,
        telefono: (j['telefono'] ?? '') as String,
        iva: (j['iva'] ?? false) as bool,
        vigenciaDias: (j['vigenciaDias'] ?? 15) as int,
        recordatorioDias: (j['recordatorioDias'] ?? 5) as int,
        integraciones: ((j['integraciones'] ?? {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as bool)),
        ciudad: (j['ciudad'] ?? '') as String,
        lat: ((j['lat'] ?? 6.2476) as num).toDouble(),
        lon: ((j['lon'] ?? -75.5658) as num).toDouble(),
        web: (j['web'] ?? 'alexpino.netlify.app') as String,
        logo: (j['logo'] ?? 'https://alexpino.netlify.app/assets/img/apple-touch-icon.png') as String,
      );
}

/// Dato para la gráfica mensual de finanzas.
class MesDato {
  final DateTime mes;
  final int valor;
  const MesDato(this.mes, this.valor);
}
