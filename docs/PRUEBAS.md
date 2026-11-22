# Pruebas — Claqueta

Dos tipos de evidencia: **pruebas automáticas** (se repiten con un comando) y **pruebas
manuales** con cuentas reales (22 nov 2026, emulador Android y navegador).

```powershell
flutter analyze   # resultado: sin avisos
flutter test      # resultado: 16 pruebas, todas pasan
```

## Pruebas automáticas (16)

Ninguna necesita internet ni claves: así se pueden correr en cualquier PC y en la sustentación.

### `test/logica_test.dart` (4) — reglas de negocio

| Prueba | Qué asegura |
|---|---|
| `formatearPesos` separa los miles con punto | Formato COP correcto |
| El total de una cotización suma, descuenta y aplica IVA | Cálculo central del negocio |
| Un trabajo calcula lo pagado y lo pendiente | Base de Finanzas |
| `hora12` convierte a formato de 12 horas | Horas legibles |

### `test/integraciones_test.dart` (7) — integraciones sin red

| Prueba | Qué asegura |
|---|---|
| El correo MIME lleva destinatario, asunto en UTF-8 y el PDF adjunto | Gmail recibe un correo válido con tildes y adjunto |
| El correo con diseño lleva texto y HTML como alternativas, y escapa el texto | Correo de marca seguro, con respaldo en texto plano |
| Las filas para Supabase llevan dueño, relaciones y el objeto completo | `filasParaSubir` arma bien `user_id`, `cliente_id` y `datos` |
| Solo se piden los permisos mínimos de Google | Los scopes son exactamente `gmail.send` y `calendar.events` |
| Los lugares de ejemplo tienen coordenadas para el mapa y el clima | El mapa y el clima siempre tienen dónde ubicarse |
| La distancia Pereira–Medellín es de unos 170 km en línea recta | La priorización por cercanía calcula bien |
| `Trabajo` guarda y recupera coordenadas y evento de Calendar | No se pierde el ID del evento al guardar |

### `test/portal_cliente_test.dart` (4) — portal del cliente

Llena el portal con datos de ejemplo (sin Supabase) a tamaño de teléfono (390 × 844).

| Prueba | Qué asegura |
|---|---|
| `PrincipalCliente`: cada pestaña abre sin desbordes ni errores | Las 4 pestañas funcionan |
| Detalles de cotización y de rodaje se dibujan bien | Las vistas de solo lectura |
| Estados vacío, de carga y de error | El cliente nunca ve una pantalla rota |
| `fechaRelativa` | "hoy, 9:05 am", "ayer", "hace 3 días" correctos |

### `test/recorrido_clics_test.dart` (1) — recorrido clic por clic

Toca **cada elemento tocable** de las 17 pantallas del realizador, empezando siempre desde
los datos de ejemplo, y escribe el informe en [PRUEBA_CLICS.md](PRUEBA_CLICS.md).

| Resultado | Valor |
|---|---|
| Elementos tocados | 180 |
| Errores | 0 |
| Desbordes a 390 × 844 | 0 |
| "Sin cambio visible" (revisar a mano) | 20 (no son errores: el toque no cambió de pantalla; ver el informe) |

## Pruebas manuales con cuentas reales (22 nov 2026)

| Flujo | Resultado |
|---|---|
| Login con Google (Android) con solo `gmail.send` y `calendar.events` | OK |
| Enviar cotización por Gmail: correo HTML de marca + PDF adjunto | OK, recibido en Gmail |
| Crear evento en Google Calendar al agendar | OK, visible en el calendario |
| Búsqueda de dirección con OpenStreetMap priorizando la ciudad del usuario | OK |
| Clima real (Open-Meteo); más de 16 días → "Estimado" | OK |
| Nube: copia automática; desinstalar → reinstalar → "Traerlos a este teléfono" | OK, datos recuperados |
| Portal: cliente en web acepta COT-0044 → *Aceptada* en la app del realizador | OK |
| Portal: solicitud del cliente aparece en "Requiere tu atención" | OK |
| Portal: la sesión del cliente se mantiene al recargar (web) | OK |

## Pendiente de probar

| Flujo | Por qué importa |
|---|---|
| Actualizar el evento de Calendar al reprogramar y borrarlo al cancelar | El código existe (`actualizarEvento`, `eliminarEvento`), falta verlo en el calendario |
| Invitación al cliente en el evento de Calendar | Requiere un correo de cliente real |
| Novedades al agendar y al registrar un pago | Que lleguen a la pestaña Novedades del cliente |
| "Pedir cambios" de punta a punta | Que el mensaje del cliente llegue a "Requiere tu atención" |
| APK en un celular real | Hasta ahora todo se probó en emulador y navegador |
