-- ==========================================================
-- LIMPIEZA: eliminar triggers, funciones y tablas
-- ==========================================================
-- Triggers en pagos y clientes
drop trigger if exists trg_pagos_aiud on pagos;
drop trigger if exists trg_clientes_ai on clientes;

-- Funciones de trigger
drop function if exists public.actualizar_estado_cliente() cascade;
drop function if exists public.generar_cronograma() cascade;

-- Tablas (cascade eliminará también índices y dependencias)
drop table if exists public.pagos      cascade;
drop table if exists public.cronograma cascade;
drop table if exists public.clientes   cascade;

-- ==========================================================
-- 1. TABLAS
-- ==========================================================
create table public.clientes (
  id               bigserial primary key,
  nombre           text    not null,
  telefono         text    not null,
  direccion        text    not null,
  negocio          text,
  monto_solicitado numeric not null default 0,
  plazo_dias       integer not null default 0,
  fecha_creacion   timestamptz not null default now(),
  fecha_primer_pago timestamptz not null,
  fecha_final      timestamptz not null,
  total_pagar      numeric not null default 0,
  cuota_diaria     numeric not null default 0,
  ultima_cuota     integer not null default 0,
  saldo_pendiente  numeric not null default 0,
  dias_atraso      integer not null default 0,
  estado_pago      text    not null default 'al_dia',
  created_at       timestamptz not null default now()
);

create table public.cronograma (
  id              bigserial primary key,
  cliente_id      bigint   not null references clientes(id) on delete cascade,
  numero_cuota    integer  not null,
  fecha_venc      date     not null,
  monto_cuota     numeric  not null,
  fecha_pagado    date,
  constraint cronograma_unico unique (cliente_id, numero_cuota)
);

create table public.pagos (
  id            bigserial primary key,
  cliente_id    bigint   not null references clientes(id) on delete cascade,
  numero_cuota  integer  not null,
  monto_pagado  numeric  not null,
  fecha_pago    timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  constraint pagos_unicos_por_cuota unique (cliente_id, numero_cuota)
);

-- ==========================================================
-- 2. Trigger / Función: generar cronograma + estado inicial
-- ==========================================================
create or replace function public.generar_cronograma()
returns trigger security definer set search_path = public as $$
declare
  v_plazo      int     := new.plazo_dias;
  v_std        numeric := new.cuota_diaria;
  v_last       numeric := new.ultima_cuota;
  v_base       date    := new.fecha_primer_pago::date;
  v_hoy        date    := date(timezone('America/Lima', now()));
  v_estado_ini text;
begin
  if v_plazo < 1 then
     raise exception 'Plazo inválido (%) para cliente %', v_plazo, new.id;
  end if;

  for i in 1..v_plazo loop
    insert into cronograma(cliente_id, numero_cuota, fecha_venc, monto_cuota)
      values(new.id, i, v_base + (i-1)*interval '1 day',
             case when i=v_plazo then v_last else v_std end);
  end loop;

  update clientes set saldo_pendiente = total_pagar where id=new.id;

  select case
    when exists(
      select 1 from cronograma
       where cliente_id=new.id and fecha_venc=v_hoy and fecha_pagado is null
    ) then 'pendiente'
    else 'al_dia'
  end into v_estado_ini;

  update clientes set estado_pago=v_estado_ini where id=new.id;
  return new;
end;
$$ language plpgsql;

create trigger trg_clientes_ai
  after insert on clientes
  for each row execute procedure public.generar_cronograma();

-- ==========================================================
-- 3. RLS (deshabilitado temporalmente)
-- ==========================================================
alter table clientes   disable row level security;
alter table cronograma disable row level security;
alter table pagos      disable row level security;

-- ==========================================================
-- 4. Trigger / Función: actualizar estado al registrar pagos
-- ==========================================================
create or replace function public.actualizar_estado_cliente()
returns trigger as $$
declare
  cid             bigint := coalesce(new.cliente_id, old.cliente_id);
  hoy             date   := date(timezone('America/Lima', now()));
  cuotas_vencidas int;
  cuota_hoy_pend  boolean;
  todas_pagadas   boolean;
  ultima_pagada   int;
  total_pagado    numeric;
  estado_final    text;
begin
  if TG_OP='INSERT' then
    update cronograma set fecha_pagado=new.fecha_pago::date
      where cliente_id=cid and numero_cuota=new.numero_cuota;
  elsif TG_OP='DELETE' then
    update cronograma set fecha_pagado=null
      where cliente_id=cid and numero_cuota=old.numero_cuota;
  end if;

  select count(*) into cuotas_vencidas from cronograma
    where cliente_id=cid and fecha_venc<hoy and fecha_pagado is null;

  select exists(
    select 1 from cronograma
     where cliente_id=cid and fecha_venc=hoy and fecha_pagado is null
  ) into cuota_hoy_pend;

  select not exists(
    select 1 from cronograma where cliente_id=cid and fecha_pagado is null
  ) into todas_pagadas;

  select coalesce(max(numero_cuota),0) into ultima_pagada
    from cronograma where cliente_id=cid and fecha_pagado is not null;

  select coalesce(sum(monto_pagado),0) into total_pagado
    from pagos where cliente_id=cid;

  if todas_pagadas then
    estado_final:='completo';
  elsif cuotas_vencidas>0 then
    estado_final:='atrasado';
  elsif cuota_hoy_pend then
    estado_final:='pendiente';
  else
    estado_final:='al_dia';
  end if;

  update clientes set
    estado_pago=estado_final,
    dias_atraso=cuotas_vencidas,
    ultima_cuota=ultima_pagada,
    saldo_pendiente=total_pagar-total_pagado
  where id=cid;

  return coalesce(new,old);
end;
$$ language plpgsql;

create trigger trg_pagos_aiud
  after insert or delete on pagos
  for each row execute procedure public.actualizar_estado_cliente();
