#!/usr/bin/env bash
# Compila la versión web de Claqueta en los servidores de Netlify.
# Usa las variables de entorno SUPABASE_URL y SUPABASE_ANON_KEY que se
# configuran en el panel de Netlify (nunca en el repositorio).
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Faltan SUPABASE_URL o SUPABASE_ANON_KEY en las variables de entorno de Netlify." >&2
  exit 1
fi

# Instala Flutter (rama estable) si no está.
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"   --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}"
