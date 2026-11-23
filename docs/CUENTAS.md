# Cuentas de Claqueta (correo y contraseña)

Desde la versión 1.0.2 el realizador **crea una cuenta con correo y contraseña**.
Google ya no es la puerta de entrada: se conecta después, en **Ajustes → Google
(Gmail y Calendar)**, solo para enviar cotizaciones y agendar rodajes.

## ¿Por qué una amiga no podía entrar con su correo?

La app de Google Cloud (pantalla de consentimiento OAuth) está en **modo de prueba**
(*Testing*). En ese modo Google **solo deja entrar a los "usuarios de prueba"**
que estén en la lista. Su correo no estaba, así que Google la rechazaba. No era
un error de Claqueta.

Con las cuentas propias esto ya **no bloquea la entrada**: cualquiera crea su
cuenta con su correo. Lo que sigue dependiendo de Google es **conectar Gmail y
Calendar**. Para que otras personas también puedan conectarlos hay dos caminos:

1. **Agregarlas como usuarios de prueba** (rápido, hasta 100 personas):
   Google Cloud → *Google Auth Platform* → **Público (Audience)** → *Usuarios de
   prueba* → **Add users** → escribe su correo → Guardar.
2. **Publicar la app** (*Publish app* en la misma página). Con los permisos que
   usa Claqueta (`gmail.send`, `calendar.events`), Google muestra el aviso
   "Google no verificó esta app" hasta que se haga su verificación; la persona
   puede continuar con *Configuración avanzada → Ir a Claqueta*.

Para la entrega del proyecto basta con la opción 1.

## ¿Dónde se guardan el correo y la contraseña?

En **Supabase Auth**, el mismo proyecto de la nube de Claqueta:

| Dato | Dónde | Cómo |
|---|---|---|
| Correo | Tabla interna `auth.users` de Supabase | Texto, solo visible para el dueño del proyecto |
| Contraseña | `auth.users` | **Cifrada con bcrypt** (hash): nadie puede leerla, ni la app ni el dueño |
| Sesión | En el teléfono (almacenamiento de la app) | Un token que Supabase renueva solo; por eso no hay que volver a escribir la contraseña hasta "Cerrar sesión" |
| Datos (clientes, cotizaciones…) | Tablas de Supabase con `user_id` | La seguridad por fila (RLS) solo deja ver las filas propias |

La app **nunca guarda la contraseña**: la envía una sola vez (por HTTPS) al entrar.

## Paso obligatorio en Supabase: confirmación de correo

Supabase, por defecto, pide **confirmar el correo** antes de entrar, y su servidor
de correo gratuito **solo envía a los miembros del equipo del proyecto**. Resultado:
tu amiga nunca recibiría el correo de confirmación.

Haz esto una vez:

1. Entra a **supabase.com** → tu proyecto.
2. Menú izquierdo → **Authentication** → **Sign In / Providers** → **Email**.
3. Desactiva **Confirm email** → **Save**.

Así la cuenta queda lista apenas se crea. (Más adelante, si quieres confirmar
correos, se configura un servidor SMTP propio en *Authentication → Emails*.)

Si no lo desactivas, la app avisa: "Te enviamos un correo para confirmar la cuenta".

## ¿Y quien ya entraba con Google (como yo)?

- En la entrada hay un enlace pequeño: **"Empecé con Google · entrar con Google"**.
  Sus datos siguen en la misma cuenta de la nube.
- Dentro, en **Ajustes → Nube → Contraseña**, puede ponerle una contraseña a esa
  cuenta para entrar también con correo y contraseña.

## Seguridad entre cuentas en el mismo teléfono

La app recuerda **qué cuenta es dueña de los datos del teléfono**. Si entra otra
cuenta, primero vacía el teléfono (sin tocar la nube) y luego trae los datos de la
cuenta nueva. Así los datos de una persona nunca se suben a la cuenta de otra.

## Pendiente

- "¿Olvidaste tu contraseña?": necesita un servidor de correo propio (SMTP) para
  enviar el enlace de recuperación. Mientras tanto, el dueño del proyecto puede
  cambiarla desde Supabase → Authentication → Users.
