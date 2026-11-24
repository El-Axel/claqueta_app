-- ===============================================================
-- CLAQUETA · Seguridad del portal del cliente
--
-- Correr DESPUÉS de portal_cliente.sql: Supabase → SQL Editor →
-- New query → pegar todo → Run. Se puede correr varias veces.
--
-- Qué agrega (para la sustentación):
-- 1. LÍMITE DE INTENTOS al canjear códigos: máximo 5 códigos
--    equivocados cada 15 minutos por dirección IP y por usuario. Con
--    códigos de 6 caracteres (31^6 ≈ 887 millones de combinaciones),
--    adivinar uno a ese ritmo tomaría miles de años.
-- 2. REVOCAR ACCESOS: el realizador puede cambiar el código de un
--    cliente y sacar a quien hubiera entrado con el código anterior.
-- 3. La función ya no "lanza" el error de código inválido: lo devuelve
--    en la respuesta. Así el intento fallido SÍ queda registrado (un
--    error deshace todo lo que hizo la función, incluido el registro).
-- ===============================================================

-- ---------- Registro de intentos ----------
create table if not exists public.intentos_codigo (
  id       bigint generated always as identity primary key,
  auth_uid uuid,
  ip       text not null,
  ok       boolean not null,
  creado   timestamptz not null default now()
);
create index if not exists intentos_codigo_ip on public.intentos_codigo (ip, creado);
create index if not exists intentos_codigo_uid on public.intentos_codigo (auth_uid, creado);

-- Nadie lee ni escribe esta tabla desde la app: solo la función.
alter table public.intentos_codigo enable row level security;
revoke all on public.intentos_codigo from anon, authenticated;

-- IP de quien llama. Supabase la pasa en las cabeceras de la petición.
create or replace function public.ip_peticion()
returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.headers', true)::json->>'cf-connecting-ip', ''),
    nullif(split_part(current_setting('request.headers', true)::json->>'x-forwarded-for', ',', 1), ''),
    'desconocida'
  );
$$;

-- ---------- Canjear el código (con límite de intentos) ----------
create or replace function public.canjear_codigo(p_codigo text)
returns json language plpgsql security definer set search_path = public as $$
declare
  max_fallos constant int := 5;
  ventana    constant interval := interval '15 minutes';
  v_ip    text := public.ip_peticion();
  fallos  int;
  fila    public.clientes%rowtype;
  negocio text;
begin
  if auth.uid() is null then
    raise exception 'Primero hay que iniciar sesión';
  end if;

  -- Limpieza: los intentos de hace más de un día ya no sirven.
  delete from public.intentos_codigo where creado < now() - interval '1 day';

  select count(*) into fallos from public.intentos_codigo
   where not ok and creado > now() - ventana
     -- Si no se conoce la IP, se limita solo por usuario (para no
     -- bloquear a todos los que comparten "desconocida").
     and ((v_ip <> 'desconocida' and ip = v_ip) or auth_uid = auth.uid());
  if fallos >= max_fallos then
    return json_build_object('error', 'bloqueado', 'espera_min', 15);
  end if;

  select * into fila from public.clientes
   where upper(codigo) = upper(trim(p_codigo)) limit 1;
  if not found then
    insert into public.intentos_codigo (auth_uid, ip, ok) values (auth.uid(), v_ip, false);
    return json_build_object('error', 'no_valido', 'restantes', max_fallos - fallos - 1);
  end if;

  insert into public.intentos_codigo (auth_uid, ip, ok) values (auth.uid(), v_ip, true);
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
grant execute on function public.canjear_codigo(text) to authenticated;

-- ---------- Revocar accesos de un cliente ----------
-- El realizador borra los accesos de SU cliente (por ejemplo, al cambiar
-- el código porque se filtró). El cliente tendrá que entrar con el nuevo.
drop policy if exists "realizador revoca accesos" on public.accesos_cliente;
create policy "realizador revoca accesos" on public.accesos_cliente for delete to authenticated
  using (realizador_id = auth.uid());
