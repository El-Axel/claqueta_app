# Conectar Gmail y Google Calendar (proyecto "Claqueta" en Google Cloud)

Mapa (OpenStreetMap) y clima (Open-Meteo) ya funcionan **sin cuenta ni clave**.
Para Gmail y Calendar la app necesita que Google la reconozca. Esto **no requiere
facturación**: si en algún momento Google pide "Activar facturación" o una tarjeta,
**no lo hagas**; no hace falta.

Estado actual del proyecto **Claqueta** (visto el 21 nov 2026): Gmail API y
Google Calendar API **ya están habilitadas**. Faltan los pasos 1 a 3.

## Datos de la app (los necesitas en el paso 2)

| Dato | Valor |
|---|---|
| Nombre del paquete | `com.example.claqueta` |
| SHA-1 (clave de depuración de este PC) | `C0:B6:BB:86:F4:AE:A6:BD:65:E6:40:D8:C9:7F:0F:5E:74:F8:B3:EC` |

> La SHA-1 identifica la firma del APK. La APK de depuración y la de `flutter build apk`
> (que en este proyecto usa la misma firma de depuración) sirven con esta huella.
> Si compilas en otro PC, ese PC tendrá otra SHA-1 y hay que agregarla también.

## 1. Pantalla de consentimiento (menú: APIs y servicios → Pantalla de consentimiento)

1. Tipo de usuario: **Externo**. Nombre de la app: **Claqueta**. Correo de asistencia y
   de contacto: tu correo.
2. **Público / Usuarios de prueba** → *Agregar usuarios* → `alexpinocaro@gmail.com`
   (y el correo de quien vaya a probar, por ejemplo el profesor). Máximo 100.
3. **Acceso a datos / Permisos (scopes)** → *Agregar o quitar permisos* → marca solo:
   - `.../auth/gmail.send`
   - `.../auth/calendar.events`
4. Deja la app en estado **Prueba** (no "Publicar"). En prueba no hace falta la
   verificación de Google; al iniciar sesión saldrá el aviso *"Google no verificó esta
   app"* → **Continuar**. Es normal en apps académicas.

## 2. ID de cliente para Android (Credenciales → Crear credenciales → ID de cliente de OAuth)

- Tipo: **Android**
- Nombre: `Claqueta Android`
- Nombre del paquete: `com.example.claqueta`
- Huella SHA-1: la de la tabla de arriba.

Este cliente no tiene secreto. No hay que copiar nada de él: Google lo reconoce por el
paquete y la firma.

## 3. ID de cliente "web" (lo pide Android para iniciar sesión)

- Crear credenciales → ID de cliente de OAuth → Tipo: **Aplicación web**
- Nombre: `Claqueta servidor` (no hace falta poner URIs).
- Al crearlo verás **ID de cliente** y **Secreto del cliente**.
  - Copia **solo el ID de cliente** (termina en `.apps.googleusercontent.com`). Es público.
  - **El secreto no se usa ni se pega en ningún lado** (ni en el código ni en el chat).

## 4. Ejecutar la app con Google

En la carpeta del proyecto (cambia el valor por tu ID de cliente web):

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=TU_ID.apps.googleusercontent.com
```

Para el APK de la entrega:

```powershell
flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=TU_ID.apps.googleusercontent.com
```

Sin `--dart-define` (o en la versión web) la app entra en **modo demostración**: se ven
los mismos pasos pero no se envía nada; las pantallas lo dicen.

## Qué hace cada permiso en la app

| Permiso | Dónde se usa | Qué NO puede hacer |
|---|---|---|
| `gmail.send` | Enviar cotización → "Enviar por Gmail con PDF" | Leer, borrar o buscar correos |
| `calendar.events` | Agendar trabajo (crear evento, invitar al cliente), reprogramar y cancelar | Ver otros calendarios ni su configuración |

## Si algo falla

- *"Google no aceptó la configuración"* o el selector se cierra solo: revisa que el
  paquete y la SHA-1 del paso 2 sean exactos y que tu correo esté en usuarios de prueba.
- *"Calendar respondió 403"*: la API no está habilitada o falta el permiso en el paso 1.3.
- Los cambios en Google Cloud pueden tardar unos minutos en aplicarse.
