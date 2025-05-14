

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."_crear_cronograma_aux"("p_cliente_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_plazo        INTEGER;
  v_std          NUMERIC;
  v_last         NUMERIC;
  v_fecha_inicio DATE;
  i              INTEGER;
BEGIN
  SELECT plazo_dias, cuota_diaria, ultima_cuota, fecha_primer_pago::date
    INTO v_plazo, v_std, v_last, v_fecha_inicio
    FROM public.clientes
   WHERE id = p_cliente_id;

  FOR i IN 1..v_plazo LOOP
    INSERT INTO public.cronograma(
      cliente_id, numero_cuota, fecha_venc, monto_cuota
    ) VALUES (
      p_cliente_id,
      i,
      v_fecha_inicio + (i - 1) * INTERVAL '1 day',
      CASE WHEN i = v_plazo THEN v_last ELSE v_std END
    );
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."_crear_cronograma_aux"("p_cliente_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_generar_cronograma_trg"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_hoy    date := date(timezone('America/Lima', now()));
  v_estado text;
begin
  PERFORM public.crear_cronograma_para_cliente(new.id);

  update clientes
    set saldo_pendiente = total_pagar
   where id = new.id;

  select case
    when exists(
      select 1 from cronograma
       where cliente_id=new.id
         and fecha_venc = v_hoy
         and fecha_pagado is null
    ) then 'pendiente'
    else 'al_dia'
  end into v_estado;

  update clientes
    set estado_pago = v_estado
   where id = new.id;

  return new;
end;
$$;


ALTER FUNCTION "public"."_generar_cronograma_trg"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_actualizar_estado"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  cid bigint := COALESCE(NEW.cliente_id, OLD.cliente_id);
  total_pagado numeric;
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.cronograma
      SET fecha_pagado = NEW.fecha_pago::date
    WHERE cliente_id = cid
      AND numero_cuota = NEW.numero_cuota;
  ELSE
    UPDATE public.cronograma
      SET fecha_pagado = NULL
    WHERE cliente_id = cid
      AND numero_cuota = OLD.numero_cuota;
  END IF;

  SELECT COALESCE(SUM(monto_pagado),0) INTO total_pagado
    FROM public.pagos
   WHERE cliente_id = cid;

  UPDATE public.clientes
     SET saldo_pendiente = total_pagar - total_pagado
   WHERE id = cid;

  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."_trigger_actualizar_estado"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_cierre_historial"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_plazo INTEGER;
BEGIN
  SELECT plazo_dias INTO v_plazo FROM public.clientes WHERE id = NEW.cliente_id;
  IF TG_OP = 'INSERT' AND NEW.numero_cuota = v_plazo THEN
    PERFORM public.crear_historial_cerrado(NEW.cliente_id);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_cierre_historial"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_cierre_por_refi"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  PERFORM public.crear_historial_cerrado(OLD.id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_cierre_por_refi"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_generar_cronograma"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_hoy   date := (now() AT TIME ZONE 'America/Lima')::date;
  v_fp    date := NEW.fecha_primer_pago;  -- ya es DATE
  v_estado text;
BEGIN
  PERFORM public._crear_cronograma_aux(NEW.id);

  UPDATE public.clientes
    SET saldo_pendiente     = NEW.total_pagar,
        ultima_cuota_numero = 0
   WHERE id = NEW.id;

  IF v_fp > v_hoy THEN
    v_estado := 'proximo';
  ELSIF EXISTS (
    SELECT 1 FROM public.cronograma
     WHERE cliente_id = NEW.id
       AND fecha_venc = v_hoy
       AND fecha_pagado IS NULL
  ) THEN
    v_estado := 'pendiente';
  ELSE
    v_estado := 'al_dia';
  END IF;

  UPDATE public.clientes
    SET estado_pago = v_estado
   WHERE id = NEW.id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_generar_cronograma"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_log_pago"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_fecha_venc DATE;
  v_atraso     INTEGER;
BEGIN
  SELECT fecha_venc INTO v_fecha_venc
    FROM public.cronograma
   WHERE cliente_id   = NEW.cliente_id
     AND numero_cuota = NEW.numero_cuota;

  v_atraso := GREATEST(
    0,
    (NEW.fecha_pago AT TIME ZONE 'America/Lima')::date - v_fecha_venc
  );

  INSERT INTO public.historial_eventos(cliente_id, tipo_evento, descripcion)
  VALUES (
    NEW.cliente_id,
    'Pago cuota ' || NEW.numero_cuota,
    format(
      'Cuota %s pagada el %s (%s día%s de atraso)',
      NEW.numero_cuota,
      (NEW.fecha_pago AT TIME ZONE 'America/Lima')::date,
      v_atraso,
      CASE WHEN v_atraso = 1 THEN '' ELSE 's' END
    )
  );

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_log_pago"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_refinanciar_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_total_pagado NUMERIC;
  v_max_atraso   INTEGER;
  v_count_incid  INTEGER;
  v_fecha_inicio DATE;
BEGIN
  -- Métricas del crédito antiguo
  SELECT
    COALESCE(SUM(p.monto_pagado),0),
    COALESCE(MAX(GREATEST(
      (p.fecha_pago AT TIME ZONE 'America/Lima')::date
      - cr.fecha_venc, 0
    )),0),
    COUNT(*)
  INTO v_total_pagado, v_max_atraso, v_count_incid
  FROM public.pagos p
  JOIN public.cronograma cr
    ON p.cliente_id = cr.cliente_id
   AND p.numero_cuota = cr.numero_cuota
  WHERE p.cliente_id = OLD.id;

  -- Fecha de inicio original
  SELECT MIN(fecha_venc)
    INTO v_fecha_inicio
  FROM public.cronograma
  WHERE cliente_id = OLD.id;

  -- Archiva en historial
  INSERT INTO public.cliente_historial(
    cliente_id, fecha_inicio, fecha_cierre,
    monto_solicitado, total_pagado,
    dias_totales, dias_atraso_max,
    incidencias, observaciones, calificacion
  ) VALUES (
    OLD.id,
    v_fecha_inicio,
    now(),
    OLD.monto_solicitado,
    v_total_pagado,
    OLD.plazo_dias,
    v_max_atraso,
    v_count_incid,
    NULL,
    GREATEST(0, LEAST(100, 100 - v_max_atraso*2 - v_count_incid*5))
  );

  -- *** Nuevo paso: eliminar todos los pagos del viejo crédito
  DELETE FROM public.pagos
   WHERE cliente_id = OLD.id;

  -- Regenera cronograma limpio
  DELETE FROM public.cronograma WHERE cliente_id = OLD.id;
  PERFORM public._crear_cronograma_aux(NEW.id);

  -- Evento de refinanciamiento
  INSERT INTO public.historial_eventos(
    cliente_id, tipo_evento, descripcion
  ) VALUES (
    OLD.id,
    'Refinanciamiento',
    format(
      'Refinanciado a S/%s en %s días (nuevo inicio %s)',
      to_char(NEW.monto_solicitado,'FM999999.00'),
      NEW.plazo_dias,
      (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date
    )
  );

  -- Ajusta saldo pendiente al nuevo total
  UPDATE public.clientes
     SET saldo_pendiente = NEW.total_pagar
   WHERE id = NEW.id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_refinanciar_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_trigger_regenerar_cronograma"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  DELETE FROM public.cronograma WHERE cliente_id = NEW.id;
  PERFORM public._crear_cronograma_aux(NEW.id);

  UPDATE public.clientes
    SET saldo_pendiente     = NEW.total_pagar,
        ultima_cuota_numero = 0
   WHERE id = NEW.id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_regenerar_cronograma"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_validar_recalcular_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_tasa      NUMERIC;
  v_total     NUMERIC;
  v_std       NUMERIC;
  v_last      NUMERIC;
  v_inicio    DATE;
BEGIN
  IF NEW.monto_solicitado <= 0 THEN
    RAISE EXCEPTION 'monto_solicitado debe ser > 0';
  ELSIF NEW.plazo_dias NOT IN (12,24) THEN
    RAISE EXCEPTION 'plazo_dias inválido';
  END IF;

  v_inicio := (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date;
  v_tasa   := CASE WHEN NEW.plazo_dias=12 THEN 10 ELSE 20 END;
  v_total  := NEW.monto_solicitado * (1 + v_tasa/100);
  v_std    := floor(v_total / NEW.plazo_dias);
  v_last   := v_total - v_std * (NEW.plazo_dias-1);

  NEW.total_pagar     := v_total;
  NEW.cuota_diaria    := v_std;
  NEW.ultima_cuota    := v_last;
  NEW.fecha_final     := v_inicio + (NEW.plazo_dias-1)*INTERVAL '1 day';
  NEW.saldo_pendiente := v_total;
  NEW.dias_atraso     := 0;
  NEW.estado_pago     := CASE
    WHEN v_inicio > (now() AT TIME ZONE 'America/Lima')::date THEN 'proximo'
    ELSE 'al_dia'
  END;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_validar_recalcular_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_validar_y_recalcular_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Lima')::date;
  v_tasa  numeric;
  v_total numeric;
  v_std   numeric;
  v_last  numeric;
BEGIN
  IF NEW.fecha_primer_pago < v_today THEN
    RAISE EXCEPTION 'fecha_primer_pago (%) debe ser ≥ hoy (Lima: %)',
      NEW.fecha_primer_pago, v_today;
  END IF;

  IF NEW.monto_solicitado <= 0 THEN
    RAISE EXCEPTION 'monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
  ELSIF NEW.plazo_dias NOT IN (12, 24) THEN
    RAISE EXCEPTION 'plazo_dias (%) inválido', NEW.plazo_dias;
  END IF;

  v_tasa  := CASE WHEN NEW.plazo_dias = 12 THEN 10 ELSE 20 END;
  v_total := NEW.monto_solicitado * (1 + v_tasa/100);
  v_std   := ceil(v_total / NEW.plazo_dias);
  v_last  := v_total - v_std * (NEW.plazo_dias - 1);

  NEW.total_pagar         := v_total;
  NEW.cuota_diaria        := v_std;
  NEW.ultima_cuota        := v_last;
  NEW.fecha_final         := NEW.fecha_primer_pago + (NEW.plazo_dias - 1);
  NEW.ultima_cuota_numero := 0;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_validar_y_recalcular_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_estado_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
  if TG_OP = 'INSERT' then
    update cronograma
       set fecha_pagado = new.fecha_pago::date
     where cliente_id = cid
       and numero_cuota = new.numero_cuota;
  else
    update cronograma
       set fecha_pagado = null
     where cliente_id = cid
       and numero_cuota = old.numero_cuota;
  end if;

  select count(*) into cuotas_vencidas
    from cronograma
   where cliente_id = cid
     and fecha_venc  < hoy
     and fecha_pagado is null;

  select exists(
    select 1 from cronograma
     where cliente_id = cid
       and fecha_venc = hoy
       and fecha_pagado is null
  ) into cuota_hoy_pend;

  select not exists(
    select 1 from cronograma
     where cliente_id = cid
       and fecha_pagado is null
  ) into todas_pagadas;

  select coalesce(max(numero_cuota),0) into ultima_pagada
    from cronograma
   where cliente_id = cid
     and fecha_pagado is not null;

  select coalesce(sum(monto_pagado),0) into total_pagado
    from pagos
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

  update clientes
     set estado_pago     = estado_final,
         dias_atraso     = cuotas_vencidas,
         ultima_cuota    = ultima_pagada,
         saldo_pendiente = total_pagar - total_pagado
   where id = cid;

  return coalesce(new,old);
end;
$$;


ALTER FUNCTION "public"."actualizar_estado_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_saldo_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  update clientes
  set saldo_pendiente = saldo_pendiente - new.monto_pagado
  where id = new.cliente_id;
  return new;
end;
$$;


ALTER FUNCTION "public"."actualizar_saldo_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_plazo       integer;
  v_std         numeric;
  v_last        numeric;
  v_fecha_inicio date;
  i             integer;
begin
  select plazo_dias, cuota_diaria, ultima_cuota, fecha_primer_pago::date
    into v_plazo, v_std, v_last, v_fecha_inicio
    from clientes
   where id = p_cliente_id;

  for i in 1..v_plazo loop
    insert into cronograma(cliente_id, numero_cuota, fecha_venc, monto_cuota)
    values (
      p_cliente_id,
      i,
      v_fecha_inicio + (i-1) * interval '1 day',
      case when i = v_plazo then v_last else v_std end
    );
  end loop;
end;
$$;


ALTER FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_total_pagado numeric;
  v_max_atraso   integer;
  v_count_incid  integer;
  v_score        integer;
BEGIN
  -- total pagado hasta ahora
  SELECT COALESCE(SUM(monto_pagado),0) INTO v_total_pagado
    FROM public.pagos
   WHERE cliente_id = p_cliente_id;

  -- máximo atraso (nunca negativo)
  SELECT COALESCE(MAX(GREATEST((p.fecha_pago::date - cr.fecha_venc),0)),0)
    INTO v_max_atraso
    FROM public.pagos p
    JOIN public.cronograma cr
      ON p.cliente_id = cr.cliente_id
     AND p.numero_cuota = cr.numero_cuota
   WHERE p.cliente_id = p_cliente_id;

  -- incidencias
  SELECT COUNT(*) INTO v_count_incid
    FROM public.historial_eventos
   WHERE cliente_id = p_cliente_id
     AND tipo_evento = 'Incidencia';

  -- score
  v_score := GREATEST(0, LEAST(100, 100 - v_max_atraso*2 - v_count_incid*5));

  -- inserta usando los parámetros antiguos
  INSERT INTO public.cliente_historial(
    cliente_id, fecha_inicio, fecha_cierre,
    monto_solicitado, total_pagado,
    dias_totales, dias_atraso_max,
    incidencias, observaciones, calificacion
  ) VALUES (
    p_cliente_id,
    p_fecha_inicio,
    now(),
    p_monto_orig,
    v_total_pagado,
    p_plazo_dias,
    v_max_atraso,
    v_count_incid,
    NULL,
    v_score
  );
END;
$$;


ALTER FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cli            RECORD;
  v_total_pagado   numeric;
  v_max_atraso     integer;
  v_count_incid    integer;
  v_score          integer;
  v_fecha_inicio   date;
BEGIN
  SELECT * INTO v_cli
    FROM public.clientes
   WHERE id = p_cliente_id;

  SELECT COALESCE(SUM(monto_pagado),0) INTO v_total_pagado
    FROM public.pagos
   WHERE cliente_id = p_cliente_id;

  -- Aquí solo tomamos los días de atraso => nunca negativos
  SELECT COALESCE(
           MAX(
             GREATEST(
               (p.fecha_pago AT TIME ZONE 'America/Lima')::date
               - cr.fecha_venc,
               0
             )
           ),
           0
         )
  INTO v_max_atraso
  FROM public.pagos p
  JOIN public.cronograma cr
    ON p.cliente_id = cr.cliente_id
   AND p.numero_cuota = cr.numero_cuota
  WHERE p.cliente_id = p_cliente_id;

  SELECT COUNT(*) INTO v_count_incid
    FROM public.historial_eventos
   WHERE cliente_id = p_cliente_id
     AND tipo_evento = 'Incidencia';

  v_score := GREATEST(0, LEAST(100, 100 - v_max_atraso*2 - v_count_incid*5));

  SELECT MIN(fecha_venc) INTO v_fecha_inicio
    FROM public.cronograma
   WHERE cliente_id = p_cliente_id;

  INSERT INTO public.cliente_historial(
    cliente_id,
    fecha_inicio,
    fecha_cierre,
    monto_solicitado,
    total_pagado,
    dias_totales,
    dias_atraso_max,
    incidencias,
    observaciones,
    calificacion
  )
  VALUES (
    p_cliente_id,
    v_fecha_inicio,
    now(),
    v_cli.monto_solicitado,
    v_total_pagado,
    v_cli.plazo_dias,
    v_max_atraso,
    v_count_incid,
    NULL,
    v_score
  );
END;
$$;


ALTER FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalcular_datos_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  cliente_id_var        bigint := coalesce(new.cliente_id, old.cliente_id);
  total_pagado          numeric;
  ultima_cuota_pagada   int;
  fecha_inicio          date;
  total_a_pagar         numeric;
  dias_transcurridos    int;
  atraso                int;
  estado                text;
  fecha_ult_pago_ts     timestamptz;
begin
  -- a) Suma de pagos
  select coalesce(sum(monto_pagado), 0)
    into total_pagado
  from pagos
  where cliente_id = cliente_id_var;

  -- b) Última cuota
  select coalesce(max(numero_cuota), 0)
    into ultima_cuota_pagada
  from pagos
  where cliente_id = cliente_id_var;

  -- c) Fecha de primer pago y total a pagar
  select date(fecha_primer_pago), total_pagar
    into fecha_inicio, total_a_pagar
  from clientes
  where id = cliente_id_var;

  -- d) Fecha del último pago
  select max(fecha_pago)
    into fecha_ult_pago_ts
  from pagos
  where cliente_id = cliente_id_var;

  -- e) Días desde el primer pago
  dias_transcurridos := 
    date(timezone('America/Lima', now())) 
    - fecha_inicio;

  -- f) Lógica de estado:
  if total_pagado >= total_a_pagar then
    estado := 'completo';
    atraso := 0;

  -- si el último pago fue justo AYER (cuota = dias_transcurridos)
  elsif ultima_cuota_pagada = dias_transcurridos
    and date(timezone('America/Lima', fecha_ult_pago_ts))
        = date(timezone('America/Lima', now())) - 1 then
    estado := 'pendiente';
    atraso := 0;

  -- si falta alguna cuota anterior a HOY
  elsif ultima_cuota_pagada < dias_transcurridos then
    estado := 'atrasado';
    atraso := dias_transcurridos - ultima_cuota_pagada;

  else
    -- ya pagó la cuota de hoy o se adelantó
    estado := 'al_dia';
    atraso := 0;
  end if;

  -- g) Actualizar cliente
  update clientes
    set saldo_pendiente     = total_a_pagar - total_pagado,
        ultima_cuota        = ultima_cuota_pagada,
        dias_atraso         = atraso,
        estado_pago         = estado,
        fecha_ultimo_pago   = fecha_ult_pago_ts
  where id = cliente_id_var;

  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."recalcular_datos_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."regenerar_cronograma_on_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_changed boolean := false;
begin
  if OLD.monto_solicitado   <> NEW.monto_solicitado then v_changed := true; end if;
  if OLD.plazo_dias        <> NEW.plazo_dias        then v_changed := true; end if;
  if OLD.fecha_primer_pago <> NEW.fecha_primer_pago then v_changed := true; end if;

  if v_changed then
    delete from cronograma where cliente_id = NEW.id;
    PERFORM public.crear_cronograma_para_cliente(NEW.id);
  end if;

  return NEW;
end;
$$;


ALTER FUNCTION "public"."regenerar_cronograma_on_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validar_y_recalcular_cliente"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_tasa  numeric;
  v_total numeric;
  v_std   numeric;
  v_last  numeric;
begin
  if NEW.monto_solicitado <= 0 then
    raise exception 'El monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
  end if;
  if NEW.plazo_dias not in (12,24) then
    raise exception 'El plazo_dias (%) no es válido (solo 12 o 24)', NEW.plazo_dias;
  end if;
  if NEW.fecha_primer_pago < now()::date + 1 then
    raise exception 'La fecha_primer_pago (%) debe ser ≥ mañana', NEW.fecha_primer_pago;
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


ALTER FUNCTION "public"."validar_y_recalcular_cliente"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validar_y_recalcular_cliente_upd"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  return public.validar_y_recalcular_cliente();
end;
$$;


ALTER FUNCTION "public"."validar_y_recalcular_cliente_upd"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."cliente_historial" (
    "id" bigint NOT NULL,
    "cliente_id" bigint NOT NULL,
    "fecha_cierre" timestamp with time zone NOT NULL,
    "monto_solicitado" numeric NOT NULL,
    "total_pagado" numeric NOT NULL,
    "dias_totales" integer NOT NULL,
    "dias_atraso_max" integer NOT NULL,
    "incidencias" integer DEFAULT 0 NOT NULL,
    "observaciones" "text",
    "calificacion" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fecha_inicio" "date"
);


ALTER TABLE "public"."cliente_historial" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."cliente_historial_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."cliente_historial_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cliente_historial_id_seq" OWNED BY "public"."cliente_historial"."id";



CREATE TABLE IF NOT EXISTS "public"."clientes" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "telefono" "text" NOT NULL,
    "direccion" "text" NOT NULL,
    "negocio" "text",
    "monto_solicitado" numeric DEFAULT 0 NOT NULL,
    "plazo_dias" integer DEFAULT 0 NOT NULL,
    "fecha_creacion" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fecha_final" timestamp with time zone NOT NULL,
    "total_pagar" numeric DEFAULT 0 NOT NULL,
    "cuota_diaria" numeric DEFAULT 0 NOT NULL,
    "ultima_cuota" numeric DEFAULT 0 NOT NULL,
    "saldo_pendiente" numeric DEFAULT 0 NOT NULL,
    "dias_atraso" integer DEFAULT 0 NOT NULL,
    "estado_pago" "text" DEFAULT 'al_dia'::"text" NOT NULL,
    "ultima_cuota_numero" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fecha_primer_pago_date" "date",
    "fecha_primer_pago" "date"
);


ALTER TABLE "public"."clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clientes_backup" (
    "id" bigint,
    "nombre" "text",
    "telefono" "text",
    "direccion" "text",
    "negocio" "text",
    "monto_solicitado" numeric,
    "plazo_dias" integer,
    "fecha_creacion" timestamp with time zone,
    "fecha_primer_pago" timestamp with time zone,
    "fecha_final" timestamp with time zone,
    "total_pagar" numeric,
    "cuota_diaria" numeric,
    "ultima_cuota" numeric,
    "saldo_pendiente" numeric,
    "dias_atraso" integer,
    "estado_pago" "text",
    "ultima_cuota_numero" integer,
    "created_at" timestamp with time zone
);


ALTER TABLE "public"."clientes_backup" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."clientes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."clientes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."clientes_id_seq" OWNED BY "public"."clientes"."id";



CREATE TABLE IF NOT EXISTS "public"."cronograma" (
    "id" bigint NOT NULL,
    "cliente_id" bigint NOT NULL,
    "numero_cuota" integer NOT NULL,
    "fecha_venc" "date" NOT NULL,
    "monto_cuota" numeric NOT NULL,
    "fecha_pagado" "date"
);


ALTER TABLE "public"."cronograma" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."cronograma_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."cronograma_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cronograma_id_seq" OWNED BY "public"."cronograma"."id";



CREATE TABLE IF NOT EXISTS "public"."historial_eventos" (
    "id" bigint NOT NULL,
    "cliente_id" bigint NOT NULL,
    "fecha_evento" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tipo_evento" "text" DEFAULT 'Incidencia'::"text" NOT NULL,
    "descripcion" "text"
);


ALTER TABLE "public"."historial_eventos" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."historial_eventos_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."historial_eventos_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."historial_eventos_id_seq" OWNED BY "public"."historial_eventos"."id";



CREATE TABLE IF NOT EXISTS "public"."pagos" (
    "id" bigint NOT NULL,
    "cliente_id" bigint NOT NULL,
    "numero_cuota" integer NOT NULL,
    "monto_pagado" numeric NOT NULL,
    "fecha_pago" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pagos" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."pagos_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."pagos_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."pagos_id_seq" OWNED BY "public"."pagos"."id";



CREATE OR REPLACE VIEW "public"."v_cliente_historial_completo" AS
 WITH "pagos_detalle" AS (
         SELECT "p"."cliente_id",
            "min"("cr"."fecha_venc") AS "fecha_inicio",
            "max"(("p"."fecha_pago" AT TIME ZONE 'America/Lima'::"text")) AS "fecha_cierre_real",
            "sum"("p"."monto_pagado") AS "total_pagado",
            "max"(((("p"."fecha_pago" AT TIME ZONE 'America/Lima'::"text"))::"date" - "cr"."fecha_venc")) AS "dias_atraso_max"
           FROM ("public"."pagos" "p"
             JOIN "public"."cronograma" "cr" ON ((("p"."cliente_id" = "cr"."cliente_id") AND ("p"."numero_cuota" = "cr"."numero_cuota"))))
          GROUP BY "p"."cliente_id"
        ), "cliente_base" AS (
         SELECT "c"."id" AS "cliente_id",
            "c"."monto_solicitado",
            "c"."plazo_dias" AS "dias_totales"
           FROM "public"."clientes" "c"
        )
 SELECT "cb"."cliente_id",
    "pd"."fecha_inicio",
    "pd"."fecha_cierre_real",
    "cb"."monto_solicitado",
    "pd"."total_pagado",
    "cb"."dias_totales",
    GREATEST("pd"."dias_atraso_max", 0) AS "dias_atraso_max"
   FROM ("cliente_base" "cb"
     LEFT JOIN "pagos_detalle" "pd" ON (("pd"."cliente_id" = "cb"."cliente_id")));


ALTER TABLE "public"."v_cliente_historial_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_clientes_con_estado" AS
 WITH "mora" AS (
         SELECT "cr"."cliente_id",
            "count"(*) FILTER (WHERE (("cr"."fecha_venc" < (("now"() AT TIME ZONE 'America/Lima'::"text"))::"date") AND ("cr"."fecha_pagado" IS NULL))) AS "cuotas_vencidas",
            (EXISTS ( SELECT 1
                   FROM "public"."cronograma" "c2"
                  WHERE (("c2"."cliente_id" = "cr"."cliente_id") AND ("c2"."fecha_venc" = (("now"() AT TIME ZONE 'America/Lima'::"text"))::"date") AND ("c2"."fecha_pagado" IS NULL)))) AS "cuota_hoy_pendiente",
            (NOT (EXISTS ( SELECT 1
                   FROM "public"."cronograma" "c3"
                  WHERE (("c3"."cliente_id" = "cr"."cliente_id") AND ("c3"."fecha_pagado" IS NULL))))) AS "todas_pagadas"
           FROM "public"."cronograma" "cr"
          GROUP BY "cr"."cliente_id"
        ), "ranked_scores" AS (
         SELECT "ch"."cliente_id",
            "ch"."calificacion" AS "score_local",
            "row_number"() OVER (PARTITION BY "ch"."cliente_id" ORDER BY "ch"."fecha_cierre" DESC) AS "rn"
           FROM "public"."cliente_historial" "ch"
        ), "agg_scores" AS (
         SELECT "rs"."cliente_id",
            "round"("avg"("rs"."score_local"), 0) AS "score_actual",
            true AS "has_history"
           FROM "ranked_scores" "rs"
          WHERE ("rs"."rn" <= 5)
          GROUP BY "rs"."cliente_id"
        )
 SELECT "cli"."id",
    "cli"."nombre",
    "cli"."telefono",
    "cli"."direccion",
    "cli"."negocio",
    "cli"."monto_solicitado",
    "cli"."plazo_dias",
    "cli"."fecha_creacion",
    "cli"."fecha_primer_pago",
    "cli"."fecha_final",
    "cli"."total_pagar",
    "cli"."cuota_diaria",
    "cli"."ultima_cuota",
    "cli"."saldo_pendiente",
    "m"."cuotas_vencidas" AS "dias_reales",
        CASE
            WHEN ("cli"."fecha_primer_pago" > (("now"() AT TIME ZONE 'America/Lima'::"text"))::"date") THEN 'proximo'::"text"
            WHEN "m"."todas_pagadas" THEN 'completo'::"text"
            WHEN ("m"."cuotas_vencidas" > 0) THEN 'atrasado'::"text"
            WHEN "m"."cuota_hoy_pendiente" THEN 'pendiente'::"text"
            ELSE 'al_dia'::"text"
        END AS "estado_real",
    COALESCE("a"."score_actual", (100)::numeric) AS "score_actual",
    COALESCE("a"."has_history", false) AS "has_history"
   FROM (("public"."clientes" "cli"
     LEFT JOIN "mora" "m" ON (("m"."cliente_id" = "cli"."id")))
     LEFT JOIN "agg_scores" "a" ON (("a"."cliente_id" = "cli"."id")));


ALTER TABLE "public"."v_clientes_con_estado" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_creditos_cerrados" AS
 SELECT "cliente_historial"."id" AS "historial_id",
    "cliente_historial"."cliente_id" AS "credito_id",
    "cliente_historial"."fecha_inicio",
    "cliente_historial"."fecha_cierre" AS "fecha_cierre_real",
    "cliente_historial"."monto_solicitado",
    "cliente_historial"."total_pagado",
    "cliente_historial"."dias_totales",
    "cliente_historial"."dias_atraso_max",
    "cliente_historial"."incidencias",
    "cliente_historial"."observaciones",
    "cliente_historial"."calificacion"
   FROM "public"."cliente_historial"
  ORDER BY "cliente_historial"."fecha_cierre";


ALTER TABLE "public"."v_creditos_cerrados" OWNER TO "postgres";


ALTER TABLE ONLY "public"."cliente_historial" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cliente_historial_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."clientes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."clientes_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."cronograma" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cronograma_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."historial_eventos" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."historial_eventos_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."pagos" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pagos_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."cliente_historial"
    ADD CONSTRAINT "cliente_historial_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cronograma"
    ADD CONSTRAINT "cronograma_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cronograma"
    ADD CONSTRAINT "cronograma_unico" UNIQUE ("cliente_id", "numero_cuota");



ALTER TABLE ONLY "public"."historial_eventos"
    ADD CONSTRAINT "historial_eventos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_unicos_por_cuota" UNIQUE ("cliente_id", "numero_cuota");



CREATE OR REPLACE TRIGGER "trg_clientes_ai" AFTER INSERT ON "public"."clientes" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_generar_cronograma"();



CREATE OR REPLACE TRIGGER "trg_clientes_bi_insert" BEFORE INSERT ON "public"."clientes" FOR EACH ROW EXECUTE FUNCTION "public"."_validar_y_recalcular_cliente"();



CREATE OR REPLACE TRIGGER "trg_clientes_bi_update" BEFORE UPDATE ON "public"."clientes" FOR EACH ROW WHEN ((("old"."fecha_primer_pago" IS DISTINCT FROM "new"."fecha_primer_pago") OR ("old"."monto_solicitado" IS DISTINCT FROM "new"."monto_solicitado") OR ("old"."plazo_dias" IS DISTINCT FROM "new"."plazo_dias"))) EXECUTE FUNCTION "public"."_validar_y_recalcular_cliente"();



CREATE OR REPLACE TRIGGER "trg_clientes_term_update" BEFORE UPDATE ON "public"."clientes" FOR EACH ROW WHEN ((("old"."monto_solicitado" IS DISTINCT FROM "new"."monto_solicitado") OR ("old"."plazo_dias" IS DISTINCT FROM "new"."plazo_dias"))) EXECUTE FUNCTION "public"."_validar_y_recalcular_cliente"();



CREATE OR REPLACE TRIGGER "trg_log_pago" AFTER INSERT ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_log_pago"();



CREATE OR REPLACE TRIGGER "trg_pagos_aiud" AFTER INSERT OR DELETE ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_actualizar_estado"();



CREATE OR REPLACE TRIGGER "trg_pagos_cierre" AFTER INSERT ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_cierre_historial"();



CREATE OR REPLACE TRIGGER "trg_refinanciar_cliente" AFTER UPDATE OF "monto_solicitado", "plazo_dias", "fecha_primer_pago" ON "public"."clientes" FOR EACH ROW WHEN ((("old"."monto_solicitado" IS DISTINCT FROM "new"."monto_solicitado") OR ("old"."plazo_dias" IS DISTINCT FROM "new"."plazo_dias") OR ("old"."fecha_primer_pago" IS DISTINCT FROM "new"."fecha_primer_pago"))) EXECUTE FUNCTION "public"."_trigger_refinanciar_cliente"();



ALTER TABLE ONLY "public"."cliente_historial"
    ADD CONSTRAINT "cliente_historial_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cronograma"
    ADD CONSTRAINT "cronograma_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."historial_eventos"
    ADD CONSTRAINT "historial_eventos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."_crear_cronograma_aux"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."_crear_cronograma_aux"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."_crear_cronograma_aux"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."_generar_cronograma_trg"() TO "anon";
GRANT ALL ON FUNCTION "public"."_generar_cronograma_trg"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_generar_cronograma_trg"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_actualizar_estado"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_actualizar_estado"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_actualizar_estado"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_cierre_historial"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_cierre_historial"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_cierre_historial"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_cierre_por_refi"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_cierre_por_refi"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_cierre_por_refi"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_generar_cronograma"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_generar_cronograma"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_generar_cronograma"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."recalcular_datos_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."recalcular_datos_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalcular_datos_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."regenerar_cronograma_on_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."regenerar_cronograma_on_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."regenerar_cronograma_on_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente_upd"() TO "anon";
GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente_upd"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validar_y_recalcular_cliente_upd"() TO "service_role";


















GRANT ALL ON TABLE "public"."cliente_historial" TO "anon";
GRANT ALL ON TABLE "public"."cliente_historial" TO "authenticated";
GRANT ALL ON TABLE "public"."cliente_historial" TO "service_role";



GRANT ALL ON SEQUENCE "public"."cliente_historial_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."cliente_historial_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."cliente_historial_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."clientes" TO "anon";
GRANT ALL ON TABLE "public"."clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes" TO "service_role";



GRANT ALL ON TABLE "public"."clientes_backup" TO "anon";
GRANT ALL ON TABLE "public"."clientes_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes_backup" TO "service_role";



GRANT ALL ON SEQUENCE "public"."clientes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."clientes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."clientes_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."cronograma" TO "anon";
GRANT ALL ON TABLE "public"."cronograma" TO "authenticated";
GRANT ALL ON TABLE "public"."cronograma" TO "service_role";



GRANT ALL ON SEQUENCE "public"."cronograma_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."cronograma_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."cronograma_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."historial_eventos" TO "anon";
GRANT ALL ON TABLE "public"."historial_eventos" TO "authenticated";
GRANT ALL ON TABLE "public"."historial_eventos" TO "service_role";



GRANT ALL ON SEQUENCE "public"."historial_eventos_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."historial_eventos_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."historial_eventos_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."pagos" TO "anon";
GRANT ALL ON TABLE "public"."pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."pagos" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pagos_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pagos_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pagos_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."v_cliente_historial_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_cliente_historial_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_cliente_historial_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_clientes_con_estado" TO "anon";
GRANT ALL ON TABLE "public"."v_clientes_con_estado" TO "authenticated";
GRANT ALL ON TABLE "public"."v_clientes_con_estado" TO "service_role";



GRANT ALL ON TABLE "public"."v_creditos_cerrados" TO "anon";
GRANT ALL ON TABLE "public"."v_creditos_cerrados" TO "authenticated";
GRANT ALL ON TABLE "public"."v_creditos_cerrados" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
