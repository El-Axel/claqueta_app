import 'package:flutter_test/flutter_test.dart';
import 'package:claqueta/modelos.dart';
import 'package:claqueta/util.dart';

// Pruebas de la lógica de negocio (no necesitan emulador):
//   flutter test
void main() {
  test('formatearPesos separa los miles con punto', () {
    expect(formatearPesos(1270000), '\$1.270.000');
    expect(formatearPesos(450), '\$450');
  });

  test('El total de una cotización suma, descuenta y aplica IVA', () {
    final c = Cotizacion(
      n: 1,
      clienteId: 1,
      proyecto: 'Prueba',
      items: [
        ItemCot(descripcion: 'Cámara', precio: 450000, cantidad: 1),
        ItemCot(descripcion: 'Edición', precio: 500000, cantidad: 2),
      ],
      descuento: 10,
      iva: true,
      creada: DateTime(2026, 11, 1),
    );
    expect(c.subtotal, 1450000);
    expect(c.valorDescuento, 145000);
    expect(c.base, 1305000);
    expect(c.valorIva, 247950);
    expect(c.total, 1552950);
  });

  test('Un trabajo calcula lo pagado y lo pendiente', () {
    final t = Trabajo(
      id: 1,
      clienteId: 1,
      titulo: 'Rodaje',
      fecha: DateTime(2026, 11, 20),
      hora: '09:00',
      lugar: 'Parque',
      valor: 1000000,
      pagos: [Pago(tipo: 'Anticipo 50%', monto: 500000, metodo: 'Efectivo', fecha: DateTime(2026, 11, 1))],
    );
    expect(t.pagado, 500000);
    expect(t.pendiente, 500000);
  });

  test('hora12 convierte a formato de 12 horas', () {
    expect(hora12('14:00'), '2:00 pm');
    expect(hora12('08:30'), '8:30 am');
    expect(hora12('00:15'), '12:15 am');
  });
}
