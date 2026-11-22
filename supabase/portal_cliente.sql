-- ===============================================================
-- CLAQUETA · Portal del cliente
--
-- Correr DESPUÉS de esquema.sql: Supabase → SQL Editor → New query →
-- pegar todo → Run. Se puede correr varias veces sin romper nada.
--
-- Cómo funciona (para la sustentación):
-- 1. Cada cliente tiene un CÓDIGO de invitación (ej. CLQ-7K4M2P).
-- 2. El cliente abre la app, entra como "anónimo" (sin correo ni
--    contraseña) y escribe su código. La función canjear_codigo()
--    lo valida y guarda en accesos_cliente: "este usuario anónimo es
--    el cliente N del realizador R".
-- 3. Reglas de seguridad por fila: el cliente puede LEER solo sus
--    cotizaciones, rodajes y novedades, y CREAR solicitudes y
--    respuestas. Nunca puede cambiar los datos del realizador.
-- 4. El realizador lee las solicitudes y respuestas desde su app y las
--    aplica (por ejemplo, "Aceptada").
-- ===============================================================

-- ---------- Código de invitación en clientes ----------
alter table public.clientes add column if not exists codigo text;
create unique index if not exists clientes_codigo_unico
  on public.clientes (upper(codigo)) where codigo is not null and codigo <> '';

-- ---------- Quién es cliente de quién ----------
create table if not exists public.accesos_cliente (
  auth_uid      uuid primary key default auth.uid() references auth.users on delete cascade,
  realizador_id uuid not null references auth.users on delete cascade,
  cliente_id    integer not null,
  creado        timestamptz not null default now()
);

-- ¿El usuario actual es el cliente "c" del realizador "r"?
-- "security definer" = se ejecuta con permisos del dueño, para poder
-- consultar accesos_cliente sin caer en un ciclo de reglas.
create or replace function public.es_cliente_de(r uuid, c integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.accesos_cliente a
    where a.auth_uid = auth.uid() and a.realizador_id = r and a.cliente_id = c
  );
$$;

create or replace function public.es_cliente_del_realizador(r uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.accesos_cliente a
    where a.auth_uid = auth.uid() and a.realizador_id = r
  );
$$;

-- Canjear el código: valida y crea el acceso. Devuelve los datos básicos.
create or replace function public.canjear_codigo(p_codigo text)
returns json language plpgsql security definer set search_path = public as $$
declare
  fila   public.clientes%rowtype;
  negocio text;
begin
  if auth.uid() is null then
    raise exception 'Primero hay que iniciar sesión';
  end if;
  select * into fila from public.clientes
   where upper(codigo) = upper(trim(p_codigo)) limit 1;
  if not found then
    raise exception 'Código no válido';
  end if;
  insert into public.accesos_cliente (auth_uid, realizador_id, cliente_id)
  values (auth.uid(), fila.user_id, fila.id)
  on conflict (auth_uid) do update
    set realizador_id = excluded.realizador_id, cliente_id = excluded.cliente_id, creado = now();
  select datos->>'negocio' into negocio from public.config where user_id = fila.user_id;
  return json_build_object(
    'realizador_id', fila.user_id,
    'cliente_id', fila.id,
    'cliente', fila.nombre,
    'negocio', coalesce(negocio, 'Tu realizador')
  );
end $$;

-- ---------- Solicitudes (el cliente pide una cotización) ----------
create table if not exists public.solicitudes (
  id              bigint generated always as identity primary key,
  realizador_id   uuid not null references auth.users on delete cascade,
  cliente_id      integer not null,
  tipo            text not null,
  descripcion     text,
  fecha_tentativa date,
  lugar           text,
  estado          text not null default 'Nueva',   -- Nueva · En cotización · Descartada
  creada          timestamptz not null default now()
);

-- ---------- Respuestas a cotizaciones ----------
create table if not exists public.respuestas (
  id            bigint generated always as identity primary key,
  realizador_id uuid not null references auth.users on delete cascade,
  cliente_id    integer not null,
  cot_n         integer not null,
  accion        text not null check (accion in ('aceptar', 'cambios')),
  mensaje       text,
  procesada     boolean not null default false,
  creada        timestamptz not null default now()
);

-- ---------- Novedades (avisos del realizador al cliente) ----------
create table if not exists public.novedades (
  id            bigint generated always as identity primary key,
  realizador_id uuid not null default auth.uid() references auth.users on delete cascade,
  cliente_id    integer not null,
  tipo          text not null,
  texto         text not null,
  creada        timestamptz not null default now()
);

-- ---------- Permisos para la app ----------
grant select, insert, update, delete
  on public.accesos_cliente, public.solicitudes, public.respuestas, public.novedades
  to authenticated;
revoke all on public.accesos_cliente, public.solicitudes, public.respuestas, public.novedades from anon;
grant execute on function public.canjear_codigo(text) to authenticated;
grant execute on function public.es_cliente_de(uuid, integer) to authenticated;
grant execute on function public.es_cliente_del_realizador(uuid) to authenticated;

alter table public.accesos_cliente enable row level security;
alter table public.solicitudes     enable row level security;
alter table public.respuestas      enable row level security;
alter table public.novedades       enable row level security;

-- ---------- Reglas de seguridad por fila ----------
-- accesos_cliente: cada cliente ve el suyo; el realizador ve quién está conectado.
drop policy if exists "ver acceso" on public.accesos_cliente;
create policy "ver acceso" on public.accesos_cliente for select to authenticated
  using (auth_uid = auth.uid() or realizador_id = auth.uid());

-- Lo que el cliente puede LEER del realizador (solo lo suyo).
drop policy if exists "cliente lee su ficha" on public.clientes;
create policy "cliente lee su ficha" on public.clientes for select to authenticated
  using (public.es_cliente_de(user_id, id));

drop policy if exists "cliente lee sus cotizaciones" on public.cotizaciones;
create policy "cliente lee sus cotizaciones" on public.cotizaciones for select to authenticated
  using (public.es_cliente_de(user_id, cliente_id));

drop policy if exists "cliente lee sus rodajes" on public.trabajos;
create policy "cliente lee sus rodajes" on public.trabajos for select to authenticated
  using (public.es_cliente_de(user_id, cliente_id));

drop policy if exists "cliente lee el negocio" on public.config;
create policy "cliente lee el negocio" on public.config for select to authenticated
  using (public.es_cliente_del_realizador(user_id));

-- Solicitudes y respuestas: el cliente crea y lee las suyas; el realizador lee y actualiza.
drop policy if exists "cliente crea solicitud" on public.solicitudes;
create policy "cliente crea solicitud" on public.solicitudes for insert to authenticated
  with check (public.es_cliente_de(realizador_id, cliente_id));
drop policy if exists "leer solicitudes" on public.solicitudes;
create policy "leer solicitudes" on public.solicitudes for select to authenticated
  using (realizador_id = auth.uid() or public.es_cliente_de(realizador_id, cliente_id));
drop policy if exists "realizador actualiza solicitud" on public.solicitudes;
create policy "realizador actualiza solicitud" on public.solicitudes for update to authenticated
  using (realizador_id = auth.uid()) with check (realizador_id = auth.uid());

drop policy if exists "cliente responde" on public.respuestas;
create policy "cliente responde" on public.respuestas for insert to authenticated
  with check (public.es_cliente_de(realizador_id, cliente_id));
drop policy if exists "leer respuestas" on public.respuestas;
create policy "leer respuestas" on public.respuestas for select to authenticated
  using (realizador_id = auth.uid() or public.es_cliente_de(realizador_id, cliente_id));
drop policy if exists "realizador procesa respuesta" on public.respuestas;
create policy "realizador procesa respuesta" on public.respuestas for update to authenticated
  using (realizador_id = auth.uid()) with check (realizador_id = auth.uid());

-- Novedades: el realizador las escribe; el cliente las lee.
drop policy if exists "realizador escribe novedades" on public.novedades;
create policy "realizador escribe novedades" on public.novedades for all to authenticated
  using (realizador_id = auth.uid()) with check (realizador_id = auth.uid());
drop policy if exists "cliente lee novedades" on public.novedades;
create policy "cliente lee novedades" on public.novedades for select to authenticated
  using (public.es_cliente_de(realizador_id, cliente_id));
