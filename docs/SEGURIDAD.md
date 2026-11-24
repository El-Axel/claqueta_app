# Seguridad del portal y de las cuentas

Respuesta a la recomendación del docente: *"un apartado web para que los clientes
revisen sus proyectos con un código, pero con seguridad importante (reCAPTCHA o
validación de usuario)"*.

## Qué protege a Claqueta

| Capa | Contra qué | Dónde |
|---|---|---|
| **CAPTCHA Cloudflare Turnstile** | Bots e IAs que crean cuentas o prueban códigos en masa | `lib/servicios/captcha.dart` + Supabase (Attack Protection) |
| **Límite de intentos del código** | Adivinar códigos de cliente a fuerza bruta | `supabase/seguridad_portal.sql` → `canjear_codigo()` |
| **Cambiar código / revocar accesos** | Código filtrado o enviado a la persona equivocada | Detalle del cliente → *Cambiar código* |
| **Seguridad por fila (RLS)** | Que un cliente vea datos de otro, o que un realizador vea los de otro | `supabase/esquema.sql`, `supabase/portal_cliente.sql` |
| **Contraseñas cifradas (bcrypt)** | Robo de contraseñas | Supabase Auth (ver [CUENTAS.md](CUENTAS.md)) |

### ¿Por qué Turnstile y no reCAPTCHA?
Hacen lo mismo (comprobar que hay una persona), pero Turnstile es **gratis sin
límite**, no muestra los típicos cuadritos de semáforos (modo invisible), no usa los
datos del visitante para publicidad y **Supabase lo trae integrado**.

### Límite de intentos
- Máximo **5 códigos equivocados cada 15 minutos**, por dirección IP y por usuario.
- Al llegar al límite, la app dice: "Demasiados intentos fallidos… espera 15 minutos".
- Los códigos tienen 6 caracteres de un alfabeto de 31 (`CLQ-XXXXXX`): unos
  **887 millones** de combinaciones. A 5 intentos cada 15 minutos, adivinar uno
  tomaría miles de años.

## Pasos para activarlo (una sola vez)

> Nada de esto cuesta dinero. Si algo pide tarjeta o "Upgrade", **para**.

### 1. Base de datos (2 minutos)
Supabase → **SQL Editor** → *New query* → pega todo `supabase/seguridad_portal.sql`
→ **Run**. Debe decir *Success*.

### 2. Crear el widget de Turnstile (5 minutos)
1. Entra a **dash.cloudflare.com** y crea una cuenta gratis (o entra con la tuya).
2. Menú izquierdo → **Turnstile** → **Add widget**.
3. Nombre: `Claqueta`. Dominio (Hostname): `claqueta-alexpino.netlify.app`.
4. Modo (*Widget Mode*): **Invisible**.
5. Crear. Cloudflare muestra dos claves:
   - **Site Key** (pública): esta sí se puede compartir; va en la app y en Netlify.
   - **Secret Key** (secreta): **solo** se pega en Supabase. Nunca en el chat ni en el código.

### 3. Poner la Site Key en la app y en la web
- `dart_defines.json` (no se sube a GitHub): agregar `"TURNSTILE_SITE_KEY": "<site key>"`.
- Netlify → *Site configuration* → *Environment variables* → **Add variable**
  `TURNSTILE_SITE_KEY` con la site key → volver a publicar.
- Compilar y publicar la **APK nueva** (Release en GitHub).

### 4. Activar el CAPTCHA en Supabase (ÚLTIMO paso)
Supabase → **Authentication** → **Attack Protection** → *Enable Captcha protection*
→ proveedor **Turnstile by Cloudflare** → pega la **Secret Key** → **Save**.

**Orden importante:** este paso va al final. Desde que se activa, Supabase rechaza
cualquier entrada sin token: las APK viejas (1.0.2 o anteriores) dejarán de poder
iniciar sesión, y hay que actualizarlas a la versión nueva.

## Cómo probarlo
- Escribir un código falso 5 veces → al sexto intento sale el aviso de espera.
- Detalle de un cliente → *Cambiar código* → el código viejo ya no entra y el
  cliente que estaba dentro sale al recargar su espacio.
- En pruebas se puede usar la clave de prueba oficial de Cloudflare
  `1x00000000000000000000BB` (invisible, siempre aprueba).
