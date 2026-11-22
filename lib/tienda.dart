import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'modelos.dart';
import 'servicios/clima_api.dart';
import 'util.dart';

// ---------------------------------------------------------------
// TIENDA: el "cerebro" de datos de la app.
// - Guarda las listas (clientes, servicios, paquetes, cotizaciones, trabajos).
// - Las guarda en el teléfono (SharedPreferences) cada vez que algo cambia.
// - Es un ChangeNotifier: cuando cambia, avisa a las pantallas que la
//   escuchan (ListenableBuilder) y ellas se redibujan solas.
// Es el equivalente en Flutter de tu localStorage "claqueta-v1" de la web.
// ---------------------------------------------------------------

final Tienda tienda = Tienda();

class Tienda extends ChangeNotifier {
  static const String _clave = 'claqueta-v2';

  // Cuando llega el pronóstico real de Open-Meteo, las pantallas que
  // escuchan la tienda se redibujan solas (sin guardar nada).
  Tienda() {
    servicioClima.addListener(notifyListeners);
  }

  List<Cliente> clientes = [];
  List<Servicio> servicios = [];
  List<Paquete> paquetes = [];
  List<Cotizacion> cotizaciones = [];
  List<Trabajo> trabajos = [];
  Config config = Config();
  bool sesion = false;

  SharedPreferences? _prefs;

  // ---------- Carga y guardado ----------
  Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    final guardado = _prefs!.getString(_clave);
    if (guardado != null) {
      try {
        _desdeJson(jsonDecode(guardado) as Map<String, dynamic>);
        if (_asegurarCodigos()) _prefs!.setString(_clave, jsonEncode(_aJson()));
        return;
      } catch (_) {
        // Si los datos guardados están dañados, se empieza con datos de ejemplo.
      }
    }
    _sembrar();
    _asegurarCodigos();
  }

  /// Se llama después de cada cambio guardado. La usa la nube (Supabase)
  /// para subir los datos. Es una "función gancho": la tienda no sabe
  /// nada de Supabase, solo avisa.
  void Function()? alGuardar;

  /// Otro gancho: avisa una "novedad" para el cliente (cotización
  /// enviada, rodaje agendado, pago recibido...). La nube la publica en
  /// el espacio del cliente.
  void Function(int clienteId, String tipo, String texto)? alNovedad;

  void avisar(int clienteId, String tipo, String texto) =>
      alNovedad?.call(clienteId, tipo, texto);

  /// Genera el código de invitación de cada cliente que aún no lo tenga.
  /// Formato CLQ-XXXXXX sin letras que se confunden (0/O, 1/I/L).
  bool _asegurarCodigos() {
    const letras = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final azar = Random.secure();
    var cambio = false;
    final usados = clientes.map((c) => c.codigo).toSet();
    for (final c in clientes) {
      if (c.codigo.isNotEmpty) continue;
      String nuevo;
      do {
        nuevo = 'CLQ-${List.generate(6, (_) => letras[azar.nextInt(letras.length)]).join()}';
      } while (usados.contains(nuevo));
      usados.add(nuevo);
      c.codigo = nuevo;
      cambio = true;
    }
    return cambio;
  }

  void _cambio() {
    _prefs?.setString(_clave, jsonEncode(_aJson()));
    notifyListeners();
    alGuardar?.call();
  }

  /// Copia completa de los datos (lo que se sube a la nube).
  Map<String, dynamic> instantanea() => _aJson();

  /// Reemplaza todos los datos por los que vienen de la nube.
  /// Conserva la sesión abierta en este teléfono.
  void reemplazarDesde(Map<String, dynamic> j) {
    final conSesion = sesion;
    _desdeJson(j);
    sesion = conSesion;
    _cambio();
  }

  Map<String, dynamic> _aJson() => {
        'version': 2,
        'sesion': sesion,
        'config': config.toJson(),
        'clientes': clientes.map((c) => c.toJson()).toList(),
        'servicios': servicios.map((s) => s.toJson()).toList(),
        'paquetes': paquetes.map((p) => p.toJson()).toList(),
        'cotizaciones': cotizaciones.map((c) => c.toJson()).toList(),
        'trabajos': trabajos.map((t) => t.toJson()).toList(),
      };

  void _desdeJson(Map<String, dynamic> j) {
    List<T> lista<T>(String clave, T Function(Map<String, dynamic>) f) =>
        ((j[clave] ?? []) as List).map((e) => f(e as Map<String, dynamic>)).toList();

    final nuevoConfig = j['config'] == null
        ? Config()
        : Config.fromJson(j['config'] as Map<String, dynamic>);
    final nuevosClientes = lista('clientes', Cliente.fromJson);
    final nuevosServicios = lista('servicios', Servicio.fromJson);
    final nuevosPaquetes = lista('paquetes', Paquete.fromJson);
    final nuevasCots = lista('cotizaciones', Cotizacion.fromJson);
    final nuevosTrabajos = lista('trabajos', Trabajo.fromJson);

    // Solo si todo se leyó bien se reemplazan los datos actuales.
    config = nuevoConfig;
    clientes = nuevosClientes;
    servicios = nuevosServicios;
    paquetes = nuevosPaquetes;
    cotizaciones = nuevasCots;
    trabajos = nuevosTrabajos;
    sesion = (j['sesion'] ?? false) as bool;
  }

  // ---------- Copia de seguridad ----------
  String exportar() => const JsonEncoder.withIndent('  ').convert(_aJson());

  /// Devuelve true si el texto era una copia válida y se restauró.
  bool importar(String texto) {
    try {
      final j = jsonDecode(texto) as Map<String, dynamic>;
      if (!j.containsKey('cotizaciones') || !j.containsKey('clientes')) return false;
      _desdeJson(j);
      _cambio();
      return true;
    } catch (_) {
      return false;
    }
  }

  void restablecer() {
    final conSesion = sesion; // restablecer datos no cierra la sesión
    _sembrar();
    sesion = conSesion;
    _cambio();
  }

  // ---------- Sesión ----------
  void iniciarSesion() {
    sesion = true;
    _cambio();
  }

  void cerrarSesion() {
    sesion = false;
    _cambio();
  }

  bool integracion(String clave) => config.integraciones[clave] ?? true;

  void cambiarIntegracion(String clave, bool valor) {
    config.integraciones[clave] = valor;
    _cambio();
  }

  void guardarConfig() => _cambio();

  /// Cambia la zona base (ciudad) usada para buscar lugares y el clima.
  void cambiarZona(String ciudad, double lat, double lon) {
    config
      ..ciudad = ciudad
      ..lat = lat
      ..lon = lon;
    _cambio();
  }

  // ---------- Búsquedas ----------
  Cliente cliente(int id) => clientes.firstWhere(
        (c) => c.id == id,
        orElse: () => Cliente(id: 0, nombre: 'Sin cliente'),
      );

  Servicio? servicio(int id) {
    for (final s in servicios) {
      if (s.id == id) return s;
    }
    return null;
  }

  Cotizacion? cotizacion(int n) {
    for (final c in cotizaciones) {
      if (c.n == n) return c;
    }
    return null;
  }

  Trabajo? trabajo(int id) {
    for (final t in trabajos) {
      if (t.id == id) return t;
    }
    return null;
  }

  Trabajo? trabajoDeCot(int n) {
    for (final t in trabajos) {
      if (t.cotN == n) return t;
    }
    return null;
  }

  int _siguiente(Iterable<int> ids) =>
      ids.fold<int>(0, (a, b) => b > a ? b : a) + 1;

  // ---------- Clientes ----------
  int guardarCliente(Cliente c) {
    if (c.id == 0) {
      c.id = _siguiente(clientes.map((x) => x.id));
      clientes.add(c);
    }
    _asegurarCodigos();
    _cambio();
    return c.id;
  }

  /// No deja eliminar un cliente que ya tiene cotizaciones o trabajos.
  bool eliminarCliente(int id) {
    final tieneCosas = cotizaciones.any((c) => c.clienteId == id) ||
        trabajos.any((t) => t.clienteId == id);
    if (tieneCosas) return false;
    clientes.removeWhere((c) => c.id == id);
    _cambio();
    return true;
  }

  // ---------- Catálogo ----------
  int guardarServicio(Servicio s) {
    if (s.id == 0) {
      s.id = _siguiente(servicios.map((x) => x.id));
      servicios.add(s);
    }
    _cambio();
    return s.id;
  }

  void eliminarServicio(int id) {
    servicios.removeWhere((s) => s.id == id);
    for (final p in paquetes) {
      p.items.remove(id);
    }
    _cambio();
  }

  int guardarPaquete(Paquete p) {
    if (p.id == 0) {
      p.id = _siguiente(paquetes.map((x) => x.id));
      paquetes.add(p);
    } else {
      final i = paquetes.indexWhere((x) => x.id == p.id);
      if (i >= 0) paquetes[i] = p;
    }
    _cambio();
    return p.id;
  }

  void eliminarPaquete(int id) {
    paquetes.removeWhere((p) => p.id == id);
    _cambio();
  }

  /// Precio de un paquete: suma de sus servicios menos el descuento.
  int precioBasePaquete(Paquete p) {
    int suma = 0;
    p.items.forEach((idServicio, cantidad) {
      final s = servicio(idServicio);
      if (s != null) suma += s.precio * cantidad;
    });
    return suma;
  }

  int precioPaquete(Paquete p) {
    final base = precioBasePaquete(p);
    return base - (base * p.descuento / 100).round();
  }

  // ---------- Cotizaciones ----------
  int guardarCotizacion(Cotizacion c) {
    if (c.n == 0) {
      c.n = cotizaciones.isEmpty ? 1 : _siguiente(cotizaciones.map((x) => x.n));
      cotizaciones.add(c);
    }
    _cambio();
    return c.n;
  }

  void eliminarCotizacion(int n) {
    cotizaciones.removeWhere((c) => c.n == n);
    _cambio();
  }

  void cambiarEstado(int n, String estado) {
    final c = cotizacion(n);
    if (c == null) return;
    final antes = c.estado;
    c.estado = estado;
    if (estado == estEnviada) c.enviada = DateTime.now();
    if (estado == estBorrador) c.enviada = null;
    _cambio();
    if (antes == estado) return;
    if (estado == estEnviada) {
      avisar(c.clienteId, 'cotizacion',
          'Te envié la cotización ${folio(c.n)} para "${c.proyecto}" por ${formatearPesos(c.total)}.');
    } else if (estado == estAceptada) {
      avisar(c.clienteId, 'cotizacion',
          'La cotización ${folio(c.n)} quedó aceptada. ¡Preparemos el rodaje!');
    }
  }

  int duplicarCotizacion(int n) {
    final o = cotizacion(n);
    if (o == null) return n;
    final copia = Cotizacion(
      n: 0,
      clienteId: o.clienteId,
      proyecto: '${o.proyecto} (copia)',
      items: o.items
          .map((i) => ItemCot(
              descripcion: i.descripcion,
              unidad: i.unidad,
              precio: i.precio,
              cantidad: i.cantidad))
          .toList(),
      descuento: o.descuento,
      iva: o.iva,
      notas: o.notas,
      creada: DateTime.now(),
      vigenciaDias: config.vigenciaDias,
    );
    return guardarCotizacion(copia);
  }

  /// Cotizaciones enviadas que llevan varios días sin respuesta.
  List<Cotizacion> get porSeguimiento {
    final lista = cotizaciones
        .where((c) =>
            c.estado == estEnviada &&
            c.enviada != null &&
            diasDesde(c.enviada!) >= config.recordatorioDias)
        .toList();
    lista.sort((a, b) => a.enviada!.compareTo(b.enviada!));
    return lista;
  }

  // ---------- Trabajos y agenda ----------
  int guardarTrabajo(Trabajo t) {
    final nuevo = t.id == 0;
    if (nuevo) {
      t.id = _siguiente(trabajos.map((x) => x.id));
      trabajos.add(t);
    }
    _cambio();
    if (nuevo) {
      avisar(t.clienteId, 'rodaje',
          'Agendé el rodaje "${t.titulo}" para el ${fechaLarga(t.fecha)} a las ${hora12(t.hora)} en ${t.lugar}.');
    }
    return t.id;
  }

  void eliminarTrabajo(int id) {
    final t = trabajo(id);
    trabajos.removeWhere((t) => t.id == id);
    _cambio();
    if (t != null) avisar(t.clienteId, 'rodaje', 'Se canceló el rodaje "${t.titulo}".');
  }

  void registrarPago(int idTrabajo, Pago p) {
    final t = trabajo(idTrabajo);
    if (t == null) return;
    t.pagos.add(p);
    _cambio();
    avisar(t.clienteId, 'pago',
        'Recibí tu pago de ${formatearPesos(p.monto)} para "${t.titulo}". '
        '${t.pendiente > 0 ? 'Pendiente: ${formatearPesos(t.pendiente)}.' : '¡Quedó pagado completo!'}');
  }

  List<Trabajo> trabajosDelDia(DateTime dia) {
    final lista = trabajos.where((t) => mismoDia(t.fecha, dia)).toList();
    lista.sort((a, b) => a.hora.compareTo(b.hora));
    return lista;
  }

  List<Trabajo> get proximos {
    final hoy = soloFecha(DateTime.now());
    final lista = trabajos.where((t) => !soloFecha(t.fecha).isBefore(hoy)).toList();
    lista.sort((a, b) => ('${a.fecha.toIso8601String()}${a.hora}')
        .compareTo('${b.fecha.toIso8601String()}${b.hora}'));
    return lista;
  }

  // Dos trabajos chocan si son el mismo día y empiezan con menos de 4 horas
  // de diferencia (un rodaje típico dura medio día).
  static const int _ventanaMinutos = 240;

  List<Trabajo> conflictosPara(DateTime fecha, String hora, {int? ignorarId}) {
    final m = minutos(hora);
    return trabajos
        .where((t) =>
            t.id != ignorarId &&
            mismoDia(t.fecha, fecha) &&
            (minutos(t.hora) - m).abs() < _ventanaMinutos)
        .toList();
  }

  Set<int> idsEnConflicto() {
    final ids = <int>{};
    for (final a in trabajos) {
      for (final b in trabajos) {
        if (a.id < b.id &&
            mismoDia(a.fecha, b.fecha) &&
            (minutos(a.hora) - minutos(b.hora)).abs() < _ventanaMinutos) {
          ids.add(a.id);
          ids.add(b.id);
        }
      }
    }
    return ids;
  }

  /// PLAN B por clima: próximos días con poca lluvia y sin cruces de agenda.
  List<DateTime> alternativas(DateTime fecha, String hora, {int? ignorarId}) {
    final resultado = <DateTime>[];
    final hoy = soloFecha(DateTime.now());
    for (int i = 1; i <= 14 && resultado.length < 3; i++) {
      final d = hoy.add(Duration(days: i));
      if (mismoDia(d, fecha)) continue;
      if (climaDe(d).lluvia >= 40) continue;
      if (conflictosPara(d, hora, ignorarId: ignorarId).isNotEmpty) continue;
      resultado.add(d);
    }
    return resultado;
  }

  // ---------- Finanzas ----------
  int get cobrado => trabajos.fold<int>(0, (a, t) => a + t.pagado);
  int get porCobrar => trabajos.fold<int>(0, (a, t) => a + t.pendiente);

  int get aceptado => cotizaciones
      .where((c) => c.estado == estAceptada)
      .fold<int>(0, (a, c) => a + c.total);

  int get enNegociacion => cotizaciones
      .where((c) => c.estado == estEnviada || c.estado == estBorrador)
      .fold<int>(0, (a, c) => a + c.total);

  int contarEstado(String estado) =>
      cotizaciones.where((c) => c.estado == estado).length;

  /// % de aceptadas entre las cotizaciones que ya tuvieron respuesta.
  int get tasaAceptacion {
    final aceptadas = contarEstado(estAceptada);
    final respondidas = aceptadas + contarEstado(estRechazada);
    if (respondidas == 0) return 0;
    return (aceptadas * 100 / respondidas).round();
  }

  List<MesDato> cobradoPorMes(int meses) {
    final ahora = DateTime.now();
    final salida = <MesDato>[];
    for (int i = meses - 1; i >= 0; i--) {
      final m = DateTime(ahora.year, ahora.month - i, 1);
      int suma = 0;
      for (final t in trabajos) {
        for (final p in t.pagos) {
          if (p.fecha.year == m.year && p.fecha.month == m.month) suma += p.monto;
        }
      }
      salida.add(MesDato(m, suma));
    }
    return salida;
  }

  /// Clientes ordenados por lo que han aceptado (mayor primero).
  List<MapEntry<Cliente, int>> get topClientes {
    final mapa = <int, int>{};
    for (final c in cotizaciones) {
      if (c.estado == estAceptada) {
        mapa[c.clienteId] = (mapa[c.clienteId] ?? 0) + c.total;
      }
    }
    final lista = mapa.entries.map((e) => MapEntry(cliente(e.key), e.value)).toList();
    lista.sort((a, b) => b.value.compareTo(a.value));
    return lista;
  }

  // ---------- Datos de ejemplo ----------
  // Las fechas se calculan desde HOY, así la demo siempre tiene
  // rodajes próximos y pagos recientes.
  void _sembrar() {
    final hoy = soloFecha(DateTime.now());
    DateTime hace(int dias) => hoy.subtract(Duration(days: dias));
    DateTime en(int dias) => hoy.add(Duration(days: dias));

    config = Config();
    sesion = false;

    clientes = [
      Cliente(id: 1, nombre: 'Café Origen S.A.S.', correo: 'compras@cafeorigen.co', telefono: '300 123 4567'),
      Cliente(id: 2, nombre: 'Estudio Marea', correo: 'hola@estudiomarea.co', telefono: '311 456 7890'),
      Cliente(id: 3, nombre: 'Lumen Films', correo: 'produccion@lumenfilms.co', telefono: '315 222 3344'),
      Cliente(id: 4, nombre: 'Brisa Radio', correo: 'info@brisaradio.co', telefono: '320 987 6543'),
    ];

    // Precios de EJEMPLO: se editan en Catálogo con las tarifas reales.
    servicios = [
      Servicio(id: 1, nombre: 'Cámara cine', unidad: 'día', precio: 450000),
      Servicio(id: 2, nombre: 'Kit de luces LED', unidad: 'día', precio: 220000),
      Servicio(id: 3, nombre: 'Operador + asistente', unidad: 'día', precio: 600000),
      Servicio(id: 4, nombre: 'Sonido directo', unidad: 'día', precio: 300000),
      Servicio(id: 5, nombre: 'Dron con piloto', unidad: 'día', precio: 350000),
      Servicio(id: 6, nombre: 'Edición y color', unidad: 'video', precio: 500000),
      Servicio(id: 7, nombre: 'Foto editada', unidad: 'foto', precio: 35000),
      Servicio(id: 8, nombre: 'Transporte y viáticos', unidad: 'servicio', precio: 120000),
    ];

    paquetes = [
      Paquete(
        id: 1,
        nombre: 'Comercial básico',
        descripcion: '1 día de rodaje con equipo completo y 1 video editado.',
        items: {1: 1, 2: 1, 3: 1, 6: 1},
        descuento: 10,
      ),
      Paquete(
        id: 2,
        nombre: 'Cobertura de evento',
        descripcion: 'Video, sonido y 10 fotos editadas del evento.',
        items: {1: 1, 3: 1, 4: 1, 6: 1, 7: 10},
        descuento: 5,
      ),
    ];

    ItemCot item(int idServicio, int cantidad) {
      final s = servicios.firstWhere((x) => x.id == idServicio);
      return ItemCot(
          descripcion: s.nombre, unidad: s.unidad, precio: s.precio, cantidad: cantidad);
    }

    cotizaciones = [
      Cotizacion(n: 37, clienteId: 1, proyecto: 'Fotografía de producto', estado: estAceptada,
          items: [ItemCot(descripcion: 'Fotografía de producto', unidad: 'servicio', precio: 780000, cantidad: 1)],
          creada: hace(52), enviada: hace(50)),
      Cotizacion(n: 38, clienteId: 3, proyecto: 'Reel para redes', estado: estEnviada,
          items: [item(6, 3)], creada: hace(7), enviada: hace(6)),
      Cotizacion(n: 39, clienteId: 4, proyecto: 'Cuña institucional', estado: estRechazada,
          items: [ItemCot(descripcion: 'Producción de cuña', unidad: 'servicio', precio: 600000, cantidad: 1)],
          creada: hace(20), enviada: hace(18)),
      Cotizacion(n: 40, clienteId: 3, proyecto: 'Videoclip', estado: estAceptada,
          items: [ItemCot(descripcion: 'Producción de videoclip', unidad: 'servicio', precio: 950000, cantidad: 1)],
          creada: hace(9), enviada: hace(8)),
      Cotizacion(n: 41, clienteId: 2, proyecto: 'Entrevista corporativa', estado: estAceptada,
          items: [
            ItemCot(descripcion: 'Equipo completo de rodaje', unidad: 'día', precio: 1800000, cantidad: 1),
            ItemCot(descripcion: 'Edición y color', unidad: 'video', precio: 600000, cantidad: 1),
          ],
          creada: hace(6), enviada: hace(5)),
      Cotizacion(n: 42, clienteId: 1, proyecto: 'Comercial 30"', estado: estBorrador,
          items: [item(1, 1), item(2, 1), item(3, 1)], creada: hace(1)),
    ];

    trabajos = [
      Trabajo(
        id: 1, cotN: 37, clienteId: 1, titulo: 'Fotografía de producto',
        fecha: hace(44), hora: '10:00', lugar: 'Jardín Botánico', zona: 'Chagualo, Medellín',
        valor: 780000, enCalendar: true,
        pagos: [
          Pago(tipo: 'Anticipo 50%', monto: 390000, metodo: 'Transferencia', fecha: hace(48)),
          Pago(tipo: 'Saldo', monto: 390000, metodo: 'Transferencia', fecha: hace(43)),
        ],
      ),
      Trabajo(
        id: 2, cotN: 41, clienteId: 2, titulo: 'Entrevista corporativa',
        fecha: en(2), hora: '14:00', lugar: 'Parque Lleras', zona: 'El Poblado, Medellín',
        valor: 2400000, enCalendar: true,
        pagos: [Pago(tipo: 'Anticipo 50%', monto: 1200000, metodo: 'Transferencia', fecha: hace(3))],
      ),
      Trabajo(
        id: 3, cotN: 40, clienteId: 3, titulo: 'Videoclip',
        fecha: en(5), hora: '09:00', lugar: 'Parque de Envigado', zona: 'Envigado, Antioquia',
        valor: 950000, enCalendar: true,
      ),
    ];
  }
}
