#!/usr/bin/env bash
# Crea el historial del proyecto en commits por capas (cada uno con su mensaje).
# Úsalo UNA vez, desde la raíz del proyecto, en tu computador:
#   git init -b main
#   git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
#   bash scripts/hacer_commits.sh
#   git push -u origin main        (te pedirá tu login de GitHub; nunca lo pegues en un chat)
# Los commits usan TU nombre y correo de git (git config user.name / user.email).
set -e
c() { git add "${@:2}" && git commit -q -m "$1" && echo "ok: $1"; }

c "chore: estructura base del proyecto Flutter y dependencias" pubspec.yaml analysis_options.yaml .gitignore
c "feat(design-system): paleta Pizarrón, tipografías Krona One y Figtree, tema oscuro" lib/tema.dart
c "feat(modelos): cliente, servicio, paquete, cotización, trabajo y pago con totales" lib/modelos.dart lib/util.dart
c "feat(estado): tienda con persistencia local, CRUD, finanzas, cruces y seguimiento" lib/tienda.dart
c "test: pruebas de totales, pagos pendientes y formato de pesos" test/logica_test.dart
c "feat(ui): fondo, tarjetas, botones, nav en píldora y componentes del design system" lib/estilo.dart lib/widgets.dart
c "feat(navegación): arranque, pantalla de entrada y estructura de 5 pestañas" lib/main.dart lib/pantallas/entrada.dart lib/pantallas/principal.dart
c "feat(clientes): lista, detalle y formulario con validación" lib/pantallas/clientes.dart lib/pantallas/detalle_cliente.dart lib/pantallas/formulario_cliente.dart lib/selectores.dart
c "feat(cotizaciones): lista con filtros, nueva cotización a la carta, detalle y catálogo con paquetes" lib/pantallas/cotizar.dart lib/pantallas/nueva_cotizacion.dart lib/pantallas/detalle_cotizacion.dart lib/pantallas/catalogo.dart
c "feat(envío): PDF de cotización y catálogo, mensajes, WhatsApp y correo" lib/compartir.dart lib/pdf_documentos.dart lib/pantallas/pdf_vista.dart lib/pantallas/envio_cotizacion.dart
c "feat(agenda): semana navegable, agendar trabajo, detalle, pagos y plan B" lib/pantallas/agenda.dart lib/pantallas/agendar_trabajo.dart lib/pantallas/detalle_trabajo.dart
c "feat(finanzas): tablero con cifras, gráfica por mes y mejores clientes; inicio con alertas" lib/pantallas/finanzas.dart lib/pantallas/inicio.dart
c "feat(ajustes): integraciones, parámetros, copia de seguridad y restablecer" lib/pantallas/ajustes.dart
c "docs: README, inventario de funcionalidades, design system, arquitectura y guion de sustentación" README.md docs scripts
echo "Listo: $(git rev-list --count HEAD) commits. Ahora: git push -u origin main"
