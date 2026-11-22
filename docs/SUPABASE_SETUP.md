# Conectar Claqueta a Supabase (paso a paso)

Supabase guarda tus datos (clientes, cotizaciones, catálogo, trabajos, ajustes) en la
nube. Si desinstalas la app o cambias de teléfono, al iniciar sesión con Google los
recuperas.

> **Regla:** en ningún paso hay que pagar. Si Supabase pide tarjeta, "Upgrade" o
> "Pro", **para y avisa**. Y nunca pegues claves en el chat.

## 1. Crear la cuenta y el proyecto

1. Entra a **supabase.com** → **Start your project** → inicia sesión con **GitHub**
   (o con tu correo).
2. **New project**:
   - **Organization:** la que te crea por defecto (plan **Free**).
   - **Project name:** `claqueta`
   - **Database password:** pulsa **Generate a password** y guárdala en tu gestor de
     contraseñas. **No la pegues en el chat.** La app no la usa.
   - **Region:** *South America (São Paulo)*, la más cercana a Colombia.
   - **Create new project.** Tarda 1–2 minutos.

## 2. Crear las tablas

1. Menú izquierdo → **SQL Editor** → **New query**.
2. Abre el archivo `supabase/esquema.sql` del proyecto, copia **todo** y pégalo.
3. Pulsa **Run**. Debe decir *Success. No rows returned*.
4. Comprueba en **Table Editor** que aparecen: `clientes`, `servicios`, `paquetes`,
   `cotizaciones`, `trabajos` y `config`, cada una con el candado de **RLS** activo.

## 3. Permitir entrar con Google

1. Menú izquierdo → **Authentication** → **Sign In / Providers** → **Google** → actívalo.
2. **Client IDs:** pega tu **ID de cliente web** de Google Cloud (el que termina en
   `.apps.googleusercontent.com`, el mismo de `dart_defines.json`).
3. **Client Secret:** si el formulario lo exige, cópialo desde Google Cloud
   (Credenciales → *Claqueta servidor*) y pégalo **solo ahí, en Supabase**. Nunca en el
   chat ni en el código.
4. Activa **Skip nonce checks**. Es necesario porque el inicio de sesión de Google en
   Android no envía ese dato.
5. **Save.**

## 4. Pasarle a la app la dirección del proyecto

1. Menú izquierdo → **Project Settings** → **API** (o **Data API**).
2. Copia:
   - **Project URL** (algo como `https://abcdxyz.supabase.co`)
   - la clave **anon / public** (o **publishable**). **No** uses la `service_role` /
     `secret`: esa jamás va en la app.
3. Abre `dart_defines.json` en la carpeta del proyecto y déjalo así (con tus valores):

```json
{
  "GOOGLE_WEB_CLIENT_ID": "…(ya está)…",
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "TU-CLAVE-ANON"
}
```

`dart_defines.json` está en `.gitignore`: no se sube a GitHub.

## 5. Probar

Avísale a Claude para que reinicie la app en el emulador. Luego, en la app:
**Ajustes → Nube → Conectar**. Desde ese momento cada cambio se guarda solo.

## 6. Portal del cliente

1. **SQL Editor → New query** → pega todo `supabase/portal_cliente.sql` → **Run**.
   (Si avisa de operaciones "destructive", es por los `drop policy if exists`: confirma.)
2. **Authentication → Sign In / Providers → User Signups** → activa
   **Allow anonymous sign-ins** → **Save changes**.

Cómo funciona: cada cliente tiene un código (`CLQ-XXXXXX`, se ve en la ficha del cliente).
Se lo envías por WhatsApp; el cliente abre Claqueta → **Soy cliente · tengo un código** →
escribe el código. Entra como usuario anónimo y la base de datos solo le deja ver lo suyo.

## Para la sustentación

- La clave *anon* es pública a propósito: la protege la **seguridad por fila (RLS)**.
  Cada fila tiene un `user_id` y la regla "solo lo mío" impide leer datos ajenos.
- La app sigue funcionando **sin internet** (guarda en el teléfono) y sincroniza cuando
  hay conexión.
- En el plan gratis, un proyecto sin uso por ~7 días se pausa. Antes de presentar, abre
  la app o el panel de Supabase para despertarlo.
