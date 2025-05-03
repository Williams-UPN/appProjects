-- ==========================================================
-- LIMPIEZA: eliminar triggers, funciones y tablas antiguas
-- ==========================================================
drop trigger if exists trg_clientes_bi  on public.clientes;
drop trigger if exists trg_clientes_ai  on public.clientes;
drop trigger if exists trg_clientes_bu  on public.clientes;
drop trigger if exists trg_clientes_au  on public.clientes;
drop trigger if exists trg_pagos_aiud   on public.pagos;

drop function if exists public._validar_y_recalcular_cliente() cascade;
drop function if exists public._validar_y_recalcular_cliente_upd() cascade;
drop function if exists public._crear_cronograma_aux(bigint) cascade;
drop function if exists public._trigger_generar_cronograma() cascade;
drop function if exists public._trigger_regenerar_cronograma() cascade;
drop function if exists public._trigger_actualizar_estado() cascade;

drop table if exists public.pagos      cascade;
drop table if exists public.cronograma cascade;
drop table if exists public.clientes   cascade;


-- ==========================================================
-- 1. TABLAS
-- ==========================================================
create table public.clientes (
  id                bigserial primary key,
  nombre            text    not null,
  telefono          text    not null,
  direccion         text    not null,
  negocio           text,
  monto_solicitado  numeric not null default 0,
  plazo_dias        integer not null default 0,
  fecha_creacion    timestamptz not null default now(),
  fecha_primer_pago timestamptz not null,
  fecha_final       timestamptz not null,
  total_pagar       numeric not null default 0,
  cuota_diaria      numeric not null default 0,
  ultima_cuota      numeric not null default 0,
  saldo_pendiente   numeric not null default 0,
  dias_atraso       integer not null default 0,
  estado_pago       text    not null default 'al_dia',
  created_at        timestamptz not null default now()
);

create table public.cronograma (
  id              bigserial primary key,
  cliente_id      bigint   not null references public.clientes(id) on delete cascade,
  numero_cuota    integer  not null,
  fecha_venc      date     not null,
  monto_cuota     numeric  not null,
  fecha_pagado    date,
  constraint cronograma_unico unique (cliente_id, numero_cuota)
);

create table public.pagos (
  id            bigserial primary key,
  cliente_id    bigint   not null references public.clientes(id) on delete cascade,
  numero_cuota  integer  not null,
  monto_pagado  numeric  not null,
  fecha_pago    timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  constraint pagos_unicos_por_cuota unique (cliente_id, numero_cuota)
);


-- ==========================================================
-- 2. Función auxiliar: crear cronograma para un cliente dado
-- ==========================================================
create or replace function public._crear_cronograma_aux(p_cliente_id bigint)
returns void language plpgsql as $$
declare
  v_plazo        integer;
  v_std          numeric;
  v_last         numeric;
  v_fecha_inicio date;
  i              integer;
begin
  select plazo_dias, cuota_diaria, ultima_cuota, fecha_primer_pago::date
    into v_plazo, v_std, v_last, v_fecha_inicio
    from public.clientes
   where id = p_cliente_id;

  for i in 1..v_plazo loop
    insert into public.cronograma(cliente_id, numero_cuota, fecha_venc, monto_cuota)
    values (
      p_cliente_id,
      i,
      v_fecha_inicio + (i-1) * interval '1 day',
      case when i = v_plazo then v_last else v_std end
    );
  end loop;
end;
$$;


-- ==========================================================
-- 3. BEFORE INSERT: validar y recalcular montos + fechas
-- ==========================================================
create or replace function public._validar_y_recalcular_cliente()
returns trigger language plpgsql as $$
declare
  v_tasa  numeric;
  v_total numeric;
  v_std   numeric;
  v_last  numeric;
begin
  if NEW.monto_solicitado <= 0 then
    raise exception 'monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
  end if;
  if NEW.plazo_dias not in (12,24) then
    raise exception 'plazo_dias (%) inválido', NEW.plazo_dias;
  end if;
  -- Ahora permitimos fecha_primer_pago ≥ hoy
  if NEW.fecha_primer_pago::date < now()::date then
    raise exception 'fecha_primer_pago (%) debe ser ≥ hoy', NEW.fecha_primer_pago;
  end if;

  v_tasa  := CASE WHEN NEW.plazo_dias = 12 THEN 10 ELSE 20 END;
  v_total := NEW.monto_solicitado * (1 + v_tasa/100);
  v_std   := ceil(v_total / NEW.plazo_dias);
  v_last  := v_total - v_std * (NEW.plazo_dias - 1);

  NEW.total_pagar    := v_total;
  NEW.cuota_diaria   := v_std;
  NEW.ultima_cuota   := v_last;
  NEW.fecha_final    := NEW.fecha_primer_pago::date
                        + (NEW.plazo_dias - 1) * interval '1 day';
  return NEW;
end;
$$;

create trigger trg_clientes_bi
  before insert on public.clientes
  for each row execute procedure public._validar_y_recalcular_cliente();


-- ==========================================================
-- 4. AFTER INSERT: generar cronograma + estado inicial
-- ==========================================================
create or replace function public._trigger_generar_cronograma()
returns trigger language plpgsql as $$
declare
  v_hoy    date := now()::date;
  v_estado text;
begin
  perform public._crear_cronograma_aux(new.id);

  update public.clientes
    set saldo_pendiente = new.total_pagar
   where id = new.id;

  select case
    when exists(
      select 1 from public.cronograma
       where cliente_id=new.id
         and fecha_venc = v_hoy
         and fecha_pagado is null
    ) then 'pendiente'
    else 'al_dia'
  end into v_estado;

  update public.clientes
    set estado_pago = v_estado
   where id = new.id;

  return new;
end;
$$;

create trigger trg_clientes_ai
  after insert on public.clientes
  for each row execute procedure public._trigger_generar_cronograma();


-- ==========================================================
-- 5. BEFORE UPDATE: validar y recalcular si cambian términos
--    (duplicamos la lógica, con validación ≥ hoy)
-- ==========================================================
create or replace function public._validar_y_recalcular_cliente_upd()
returns trigger language plpgsql as $$
declare
  v_tasa  numeric;
  v_total numeric;
  v_std   numeric;
  v_last  numeric;
begin
  if NEW.monto_solicitado <> OLD.monto_solicitado
    or NEW.plazo_dias       <> OLD.plazo_dias
    or NEW.fecha_primer_pago <> OLD.fecha_primer_pago
  then
    if NEW.monto_solicitado <= 0 then
      raise exception 'monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
    end if;
    if NEW.plazo_dias not in (12,24) then
      raise exception 'plazo_dias (%) inválido', NEW.plazo_dias;
    end if;
    -- aquí también permitimos ≥ hoy
    if NEW.fecha_primer_pago::date < now()::date then
      raise exception 'fecha_primer_pago (%) debe ser ≥ hoy', NEW.fecha_primer_pago;
    end if;

    v_tasa  := CASE WHEN NEW.plazo_dias = 12 THEN 10 ELSE 20 END;
    v_total := NEW.monto_solicitado * (1 + v_tasa/100);
    v_std   := ceil(v_total / NEW.plazo_dias);
    v_last  := v_total - v_std * (NEW.plazo_dias - 1);

    NEW.total_pagar    := v_total;
    NEW.cuota_diaria   := v_std;
    NEW.ultima_cuota   := v_last;
    NEW.fecha_final    := NEW.fecha_primer_pago::date
                          + (NEW.plazo_dias - 1) * interval '1 day';
  end if;
  return NEW;
end;
$$;

create trigger trg_clientes_bu
  before update on public.clientes
  for each row execute procedure public._validar_y_recalcular_cliente_upd();


-- ==========================================================
-- 6. AFTER UPDATE: regenerar cronograma si cambian términos
-- ==========================================================
create or replace function public._trigger_regenerar_cronograma()
returns trigger language plpgsql as $$
begin
  if OLD.monto_solicitado   <> NEW.monto_solicitado
    or OLD.plazo_dias        <> NEW.plazo_dias
    or OLD.fecha_primer_pago <> NEW.fecha_primer_pago
  then
    delete from public.cronograma where cliente_id = NEW.id;
    perform public._crear_cronograma_aux(NEW.id);
  end if;
  return NEW;
end;
$$;

create trigger trg_clientes_au
  after update on public.clientes
  for each row execute procedure public._trigger_regenerar_cronograma();


-- ==========================================================
-- 7. AFTER INSERT/DELETE en pagos: actualizar estado general
-- ==========================================================
create or replace function public._trigger_actualizar_estado()
returns trigger language plpgsql as $$
declare
  cid             bigint := coalesce(new.cliente_id, old.cliente_id);
  hoy             date   := now()::date;
  cuotas_vencidas int;
  cuota_hoy_pend  boolean;
  todas_pagadas   boolean;
  ultima_pagada   int;
  total_pagado    numeric;
  estado_final    text;
begin
  if TG_OP = 'INSERT' then
    update public.cronograma
       set fecha_pagado = new.fecha_pago::date
     where cliente_id = cid
       and numero_cuota = new.numero_cuota;
  else
    update public.cronograma
       set fecha_pagado = null
     where cliente_id = cid
       and numero_cuota = old.numero_cuota;
  end if;

  select count(*) into cuotas_vencidas
    from public.cronograma
   where cliente_id = cid
     and fecha_venc  < hoy
     and fecha_pagado is null;

  select exists(
    select 1 from public.cronograma
     where cliente_id = cid
       and fecha_venc = hoy
       and fecha_pagado is null
  ) into cuota_hoy_pend;

  select not exists(
    select 1 from public.cronograma
     where cliente_id = cid
       and fecha_pagado is null
  ) into todas_pagadas;

  select coalesce(max(numero_cuota),0) into ultima_pagada
    from public.cronograma
   where cliente_id = cid
     and fecha_pagado is not null;

  select coalesce(sum(monto_pagado),0) into total_pagado
    from public.pagos
   where cliente_id = cid;

  if todas_pagadas then
    estado_final := 'completo';
  elsif cuotas_vencidas > 0 then
    estado_final := 'atrasado';
  elsif cuota_hoy_pend then
    estado_final := 'pendiente';
  else
    estado_final := 'al_dia';
  end if;

  update public.clientes
     set estado_pago     = estado_final,
         dias_atraso     = cuotas_vencidas,
         ultima_cuota    = ultima_pagada,
         saldo_pendiente = total_pagar - total_pagado
   where id = cid;

  return coalesce(new,old);
end;
$$;

create trigger trg_pagos_aiud
  after insert or delete on public.pagos
  for each row execute procedure public._trigger_actualizar_estado();


-- ==========================================================
-- 8. (Opcional) Deshabilitar RLS mientras pruebas
-- ==========================================================
alter table public.clientes   disable row level security;
alter table public.cronograma disable row level security;
alter table public.pagos      disable row level security;
