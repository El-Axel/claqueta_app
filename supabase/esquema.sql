-- ===============================================================
-- CLAQUETA · Base de datos en Supabase (PostgreSQL)
--
-- Cómo usarlo: Supabase → SQL Editor → New query → pegar todo → Run.
-- Se puede ejecutar más de una vez sin romper nada.
--
-- Ideas clave (para la sustentación):
-- 1. Cada tabla tiene user_id: el dueño de la fila. Lo pone la base de
--    datos sola con auth.uid() (el usuario que inició sesión).
-- 2. Seguridad por fila (RLS): una regla dice "solo puedes ver y
--    cambiar tus propias filas". Aunque la clave pública de la app
--    esté en el teléfono, nadie puede leer datos de otro usuario.
-- 3. Relaciones: una cotización y un trabajo pertenecen a un cliente
--    (llave foránea). Si se borra el cliente, se borra lo suyo.
-- 4. Columnas legibles (nombre, total, fecha...) para consultar y
--    filtrar, y una columna "datos" (jsonb) con el objeto completo
--    que usa la app (ítems de la cotización, pagos del trabajo...).
-- ===============================================================

-- ---------- Clientes ----------
create table if not exists public.clientes (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  id          integer not null,
  nombre      text not null,
  correo      text,
  telefono    text,
  datos       jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, id)
);

-- ---------- Catálogo: servicios y paquetes ----------
create table if not exists public.servicios (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  id          integer not null,
  nombre      text not null,
  precio      integer not null default 0,
  datos       jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.paquetes (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  id          integer not null,
  nombre      text not null,
  datos       jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, id)
);

-- ---------- Cotizaciones (pertenecen a un cliente) ----------
create table if not exists public.cotizaciones (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  n           integer not null,
  cliente_id  integer not null,
  proyecto    text not null,
  estado      text not null,
  total       integer not null default 0,
  datos       jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, n),
  foreign key (user_id, cliente_id) references public.clientes (user_id, id) on delete cascade
);

-- ---------- Trabajos / rodajes (pertenecen a un cliente) ----------
create table if not exists public.trabajos (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  id          integer not null,
  cliente_id  integer not null,
  cot_n       integer,
  titulo      text not null,
  fecha       timestamptz not null,
  lugar       text,
  valor       integer not null default 0,
  datos       jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, cliente_id) references public.clientes (user_id, id) on delete cascade
);

-- ---------- Ajustes del negocio (una fila por usuario) ----------
create table if not exists public.config (
  user_id     uuid primary key default auth.uid() references auth.users on delete cascade,
  datos       jsonb not null,
  actualizado timestamptz not null default now()
);

-- ---------- Acceso desde la app (Data API) ----------
-- Solo los usuarios que iniciaron sesión ("authenticated") pueden usar
-- las tablas; los anónimos no. Y aun así RLS limita a sus propias filas.
grant usage on schema public to authenticated;
grant select, insert, update, delete
  on public.clientes, public.servicios, public.paquetes,
     public.cotizaciones, public.trabajos, public.config
  to authenticated;
revoke all
  on public.clientes, public.servicios, public.paquetes,
     public.cotizaciones, public.trabajos, public.config
  from anon;

-- ---------- Seguridad por fila (RLS) ----------
-- Se activa en cada tabla y se crea UNA regla: "solo lo mío".
do $$
declare t text;
begin
  foreach t in array array['clientes','servicios','paquetes','cotizaciones','trabajos','config'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "solo lo mio" on public.%I', t);
    execute format(
      'create policy "solo lo mio" on public.%I for all to authenticated '
      'using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
  end loop;
end $$;
