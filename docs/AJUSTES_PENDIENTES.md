# Ajustes pendientes (lista del usuario)

Lista viva: se va llenando a medida que se revisa la app. Cada punto tiene
lo que se pidió, cómo se va a resolver y su estado.

| # | Pantalla | Pedido | Estado |
|---|---|---|---|
| 1 | Entrada / inicio de sesión | Más profesional, menos simple; quitar las píldoras Maps · Clima · Calendar · Gmail | Hecho (rama feat/entrada-pro) |
| 2 | Íconos | Nuevos íconos de marca: celular = "Blanco sobre teal"; dentro de la app, el que mejor se vea | Hecho: celular, monocromo Android 13, web, entrada y PDF |
| 1b | Entrada | Aparecía sola la ventana de Google y, al cerrarla, "Inicio de sesión cancelado" | Hecho: solo se intenta si ya habías conectado Google |

---

## 1. Entrada e inicio de sesión más profesional

**Pedido:** la pantalla de entrada se siente simple; las píldoras
"Maps · Clima · Calendar · Gmail" sobran en un inicio de sesión. Referencia:
diseño oscuro con saludo grande, campos de correo y contraseña a la vista,
"¿Olvidaste tu contraseña?", botón principal, separador "o", botón de Google
y "¿No tienes cuenta? Regístrate" abajo.

**Cómo se resolverá (propuesta):**
- Una sola pantalla de acceso con **dos pestañas o un selector**: *Realizador* /
  *Cliente* (en lugar de tres botones apilados).
- **Realizador:** logo pequeño arriba, título "Bienvenido a Claqueta" + frase
  corta, campos de **correo** y **contraseña** directamente en la pantalla (sin
  pasar a otra), enlace "¿Olvidaste tu contraseña?", botón **Entrar**, separador
  "o", botón **Continuar con Google** (ícono de Google), y abajo
  "¿No tienes cuenta? **Crear cuenta**".
- **Cliente:** campo del código de invitación y botón **Entrar**.
- Se quitan las píldoras de integraciones.
- Se mantiene la identidad de Claqueta (petróleo oscuro + arena), no el verde
  limón de la referencia.
- "¿Olvidaste tu contraseña?" depende del correo propio (SMTP, recomendación 3
  del profe): mientras tanto mostrará cómo recuperarla.
