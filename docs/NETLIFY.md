# Publicar Claqueta en Netlify (versión web)

La versión web sirve sobre todo para el **espacio del cliente**: cualquier persona abre el
enlace en el celular (Android o **iPhone**) o en el PC, toca **"Soy cliente · tengo un
código"** y entra. En la web, el lado del realizador funciona en modo demostración para
Google (Gmail/Calendar reales están en la app de Android).

## Una sola vez: conectar el repositorio

1. Entra a **app.netlify.com** → **Add new site** → **Import an existing project** →
   **GitHub** → elige `El-Axel/claqueta_app`.
2. **Branch to deploy:** la rama que quieras publicar (`main` cuando fusiones el PR).
3. **Build command** y **Publish directory**: déjalos vacíos. Los toma del archivo
   `netlify.toml` del repositorio (`bash scripts/netlify_build.sh` → `build/web`).
4. Antes de pulsar **Deploy**, abre **Add environment variables** (o después en
   **Site configuration → Environment variables**) y crea:

   | Key | Value |
   |---|---|
   | `SUPABASE_URL` | la misma de tu `dart_defines.json` |
   | `SUPABASE_ANON_KEY` | la clave **publishable** de tu `dart_defines.json` |

   Son las claves públicas: es seguro que estén en la web (las protege la seguridad por
   fila de Supabase). **Nunca** pongas aquí la clave `secret` / `service_role`.
5. **Deploy.** La primera compilación tarda unos minutos porque Netlify instala Flutter.

## Cada actualización

Haces `git push` y Netlify vuelve a compilar y publicar solo. Los usuarios ven la versión
nueva al recargar la página.

## iPhone: "instalarla" como app

En Safari → abrir el enlace → botón **Compartir** → **Añadir a pantalla de inicio**.
Queda con el ícono de Claqueta y se abre a pantalla completa.

## Si algo falla

- *"Faltan SUPABASE_URL o SUPABASE_ANON_KEY"* en el registro de Netlify: falta crear
  las variables del paso 4.
- El plan gratis de Netlify da 300 minutos de compilación al mes; cada publicación usa
  unos 3–5. Si se agotan, se puede compilar en el PC (`flutter build web --release
  --dart-define-from-file=dart_defines.json`) y arrastrar la carpeta `build/web` a
  Netlify (**Deploys → Drag and drop**).
