

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


CREATE OR REPLACE FUNCTION "public"."_trigger_log_gasto"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO public.historial_eventos(cliente_id, tipo_evento, descripcion)
  VALUES (
    NULL, -- No está asociado a cliente específico
    'Gasto registrado',
    format('Gasto %s: S/%s (%s)', 
           NEW.categoria, 
           to_char(NEW.monto,'FM999999.00'),
           COALESCE(NEW.descripcion, 'Sin descripción'))
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_trigger_log_gasto"() OWNER TO "postgres";


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
BEGIN
  -- COMENTAMOS TODO EL CÓDIGO QUE CREA HISTORIAL
  -- porque abrir_nuevo_credito_con_ubicacion ya lo hace
  
  -- Solo borramos pagos y regeneramos cronograma
  DELETE FROM public.pagos WHERE cliente_id = NEW.id;
  DELETE FROM public.cronograma WHERE cliente_id = NEW.id;
  PERFORM public._crear_cronograma_aux(NEW.id);
  
  -- Actualiza saldo
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


CREATE OR REPLACE FUNCTION "public"."_validar_gasto"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.monto <= 0 THEN
    RAISE EXCEPTION 'El monto (%) debe ser > 0', NEW.monto;
  END IF;
  
  IF NEW.categoria NOT IN ('Gasolina', 'Teléfono', 'Comida', 'Otro') THEN
    RAISE EXCEPTION 'Categoría inválida: %', NEW.categoria;
  END IF;
  
  -- Si es "Otro" debe tener descripción
  IF NEW.categoria = 'Otro' AND (NEW.descripcion IS NULL OR trim(NEW.descripcion) = '') THEN
    RAISE EXCEPTION 'La categoría "Otro" requiere descripción';
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."_validar_gasto"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."abrir_nuevo_credito"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Archiva el crédito anterior
  PERFORM public.crear_historial_cerrado(p_cliente_id);

  -- Limpia pagos y cronograma
  DELETE FROM public.pagos     WHERE cliente_id = p_cliente_id;
  DELETE FROM public.cronograma WHERE cliente_id = p_cliente_id;

  -- Actualiza la fila clientes (dispara _trigger_refinanciar_cliente)
  UPDATE public.clientes
     SET monto_solicitado  = p_monto_solicitado,
         plazo_dias        = p_plazo_dias,
         fecha_primer_pago = p_fecha_primer_pago
   WHERE id = p_cliente_id;

  -- Ya NO llamamos manualmente a _crear_cronograma_aux,
  -- porque el trigger lo hizo por nosotros.
END;
$$;


ALTER FUNCTION "public"."abrir_nuevo_credito"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."abrir_nuevo_credito_con_ubicacion"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date", "p_latitud" double precision DEFAULT NULL::double precision, "p_longitud" double precision DEFAULT NULL::double precision, "p_direccion" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cli RECORD;
  v_total_pagado numeric;
  v_max_atraso integer;
  v_count_incid integer;
  v_score integer;
  v_fecha_inicio date;
BEGIN
  -- Obtener datos del cliente actual
  SELECT * INTO v_cli FROM public.clientes WHERE id = p_cliente_id;
  
  -- Calcular métricas para el historial
  SELECT COALESCE(SUM(monto_pagado), 0) INTO v_total_pagado
  FROM public.pagos WHERE cliente_id = p_cliente_id;
  
  SELECT COALESCE(MAX(GREATEST((p.fecha_pago::date - cr.fecha_venc), 0)), 0)
  INTO v_max_atraso
  FROM public.pagos p
  JOIN public.cronograma cr ON p.cliente_id = cr.cliente_id 
    AND p.numero_cuota = cr.numero_cuota
  WHERE p.cliente_id = p_cliente_id;
  
  SELECT COUNT(*) INTO v_count_incid
  FROM public.historial_eventos
  WHERE cliente_id = p_cliente_id AND tipo_evento = 'Incidencia';
  
  v_score := GREATEST(0, LEAST(100, 100 - v_max_atraso*2 - v_count_incid*5));
  
  SELECT MIN(fecha_venc) INTO v_fecha_inicio
  FROM public.cronograma WHERE cliente_id = p_cliente_id;
  
  -- GUARDAR EN HISTORIAL CON UBICACIÓN
  INSERT INTO public.cliente_historial(
    cliente_id, fecha_inicio, fecha_cierre,
    monto_solicitado, total_pagado,
    dias_totales, dias_atraso_max,
    incidencias, observaciones, calificacion,
    latitud_cierre, longitud_cierre, direccion_cierre  -- NUEVO
  ) VALUES (
    p_cliente_id, v_fecha_inicio, now(),
    v_cli.monto_solicitado, v_total_pagado,
    v_cli.plazo_dias, v_max_atraso,
    v_count_incid, 'Refinanciado', v_score,
    p_latitud, p_longitud, p_direccion  -- NUEVO
  );
  
  -- Limpiar pagos y cronograma
  DELETE FROM public.pagos WHERE cliente_id = p_cliente_id;
  DELETE FROM public.cronograma WHERE cliente_id = p_cliente_id;
  
  -- Actualizar cliente con nuevos datos
  UPDATE public.clientes
  SET monto_solicitado = p_monto_solicitado,
      plazo_dias = p_plazo_dias,
      fecha_primer_pago = p_fecha_primer_pago
  WHERE id = p_cliente_id;
  
  -- Registrar evento con ubicación
  INSERT INTO public.historial_eventos(
    cliente_id, tipo_evento, descripcion
  ) VALUES (
    p_cliente_id,
    'Refinanciamiento',
    format(
      'Refinanciado a S/%s en %s días. Ubicación: %s',
      to_char(p_monto_solicitado, 'FM999999.00'),
      p_plazo_dias,
      COALESCE(p_direccion, 'Sin ubicación')
    )
  );
END;
$$;


ALTER FUNCTION "public"."abrir_nuevo_credito_con_ubicacion"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date", "p_latitud" double precision, "p_longitud" double precision, "p_direccion" "text") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cli RECORD;
BEGIN
  -- Cargamos solo lo que necesitamos de la tabla clientes
  SELECT monto_solicitado, fecha_primer_pago, plazo_dias
    INTO v_cli
    FROM public.clientes
   WHERE id = p_cliente_id;

  -- Llamamos a la función existente de 4 parámetros
  PERFORM public.crear_historial_cerrado(
    p_cliente_id,
    v_cli.monto_solicitado,
    v_cli.fecha_primer_pago,
    v_cli.plazo_dias
  );
END;
$$;


ALTER FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint) OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."obtener_cobranza_por_dias"("p_dias_atras" integer DEFAULT 30) RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_resultado JSON;
  v_fecha_fin DATE := (NOW() AT TIME ZONE 'America/Lima')::DATE;
  v_fecha_inicio DATE := v_fecha_fin - (p_dias_atras - 1);
BEGIN
  SELECT json_build_object(
    -- Período consultado
    'periodo', json_build_object(
      'fecha_inicio', v_fecha_inicio,
      'fecha_fin', v_fecha_fin,
      'dias_totales', p_dias_atras
    ),
    
    -- Datos para gráfico de línea/barras
    'serie_diaria', (
      SELECT json_agg(
        json_build_object(
          'fecha', dia.fecha,
          'dia_semana', TO_CHAR(dia.fecha, 'Dy'),
          'cobrado', COALESCE(cobros.monto, 0),
          'clientes', COALESCE(cobros.clientes, 0),
          'esperado', COALESCE(esperado.monto, 0),
          'efectividad', CASE
            WHEN COALESCE(esperado.monto, 0) = 0 THEN 100
            ELSE ROUND((COALESCE(cobros.monto, 0) * 100.0 / esperado.monto), 1)
          END
        ) ORDER BY dia.fecha
      )
      FROM (
        SELECT generate_series(v_fecha_inicio, v_fecha_fin, '1 day'::interval)::DATE as fecha
      ) dia
      LEFT JOIN (
        SELECT 
          (fecha_pago AT TIME ZONE 'America/Lima')::DATE as fecha,
          SUM(monto_pagado) as monto,
          COUNT(DISTINCT cliente_id) as clientes
        FROM public.pagos
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE BETWEEN v_fecha_inicio AND v_fecha_fin
        GROUP BY (fecha_pago AT TIME ZONE 'America/Lima')::DATE
      ) cobros ON cobros.fecha = dia.fecha
      LEFT JOIN (
        SELECT 
          fecha_venc as fecha,
          SUM(monto_cuota) as monto
        FROM public.cronograma
        WHERE fecha_venc BETWEEN v_fecha_inicio AND v_fecha_fin
        GROUP BY fecha_venc
      ) esperado ON esperado.fecha = dia.fecha
    ),
    
    -- Estadísticas del período
    'estadisticas', json_build_object(
      'total_cobrado', (
        SELECT COALESCE(SUM(monto_pagado), 0)
        FROM public.pagos
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE BETWEEN v_fecha_inicio AND v_fecha_fin
      ),
      'promedio_diario', (
        SELECT ROUND(AVG(monto_dia), 2)
        FROM (
          SELECT SUM(monto_pagado) as monto_dia
          FROM public.pagos
          WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE BETWEEN v_fecha_inicio AND v_fecha_fin
          GROUP BY (fecha_pago AT TIME ZONE 'America/Lima')::DATE
        ) promedios
      ),
      'mejor_dia', (
        SELECT json_build_object(
          'fecha', fecha,
          'monto', monto,
          'dia_semana', TO_CHAR(fecha, 'TMDay')
        )
        FROM (
          SELECT 
            (fecha_pago AT TIME ZONE 'America/Lima')::DATE as fecha,
            SUM(monto_pagado) as monto
          FROM public.pagos
          WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE BETWEEN v_fecha_inicio AND v_fecha_fin
          GROUP BY (fecha_pago AT TIME ZONE 'America/Lima')::DATE
          ORDER BY monto DESC
          LIMIT 1
        ) mejor
      )
    )
  );
  
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_cobranza_por_dias"("p_dias_atras" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_cobranza_por_mes"("p_numero_meses" integer DEFAULT 6) RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_resultado JSON;
  v_fecha_hoy DATE := (NOW() AT TIME ZONE 'America/Lima')::DATE;
  v_fecha_inicio DATE;
BEGIN
  -- Calcular fecha de inicio (primer día del mes hace X meses)
  v_fecha_inicio := DATE_TRUNC('month', v_fecha_hoy - (p_numero_meses || ' months')::INTERVAL);
  
  SELECT json_build_object(
    -- Información del período
    'periodo_consultado', json_build_object(
      'fecha_inicio', v_fecha_inicio,
      'fecha_fin', v_fecha_hoy,
      'numero_meses', p_numero_meses
    ),
    
    -- Detalle por mes
    'meses', (
      SELECT json_agg(mes ORDER BY año DESC, mes_num DESC)
      FROM (
        SELECT json_build_object(
          'año', año,
          'mes_numero', mes_num,
          'mes_nombre', TO_CHAR(primer_dia, 'TMMonth'),
          'fecha_inicio', primer_dia,
          'fecha_fin', ultimo_dia,
          'total_cobrado', COALESCE(monto_mes, 0),
          'clientes_pagaron', COALESCE(clientes_mes, 0),
          'promedio_diario', ROUND(COALESCE(monto_mes, 0) / dias_mes, 2),
          'dias_cobro', COALESCE(dias_activos, 0),
          'total_esperado', COALESCE(esperado_mes, 0),
          'efectividad', CASE
            WHEN COALESCE(esperado_mes, 0) = 0 THEN 100
            ELSE ROUND((COALESCE(monto_mes, 0) * 100.0 / esperado_mes), 1)
          END,
          'detalle_semanas', semanas_del_mes
        ) as mes,
        año,
        mes_num
        FROM (
          -- Generar meses y sus datos
          SELECT 
            EXTRACT(YEAR FROM mes.fecha)::INT as año,
            EXTRACT(MONTH FROM mes.fecha)::INT as mes_num,
            DATE_TRUNC('month', mes.fecha)::DATE as primer_dia,
            (DATE_TRUNC('month', mes.fecha) + INTERVAL '1 month' - INTERVAL '1 day')::DATE as ultimo_dia,
            EXTRACT(DAY FROM DATE_TRUNC('month', mes.fecha) + INTERVAL '1 month' - INTERVAL '1 day')::INT as dias_mes,
            -- Cobrado en el mes
            (
              SELECT SUM(monto_pagado)
              FROM public.pagos
              WHERE DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = DATE_TRUNC('month', mes.fecha)
            ) as monto_mes,
            -- Clientes que pagaron
            (
              SELECT COUNT(DISTINCT cliente_id)
              FROM public.pagos
              WHERE DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = DATE_TRUNC('month', mes.fecha)
            ) as clientes_mes,
            -- Días con cobro
            (
              SELECT COUNT(DISTINCT (fecha_pago AT TIME ZONE 'America/Lima')::DATE)
              FROM public.pagos
              WHERE DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = DATE_TRUNC('month', mes.fecha)
            ) as dias_activos,
            -- Monto esperado
            (
              SELECT SUM(monto_cuota)
              FROM public.cronograma
              WHERE DATE_TRUNC('month', fecha_venc) = DATE_TRUNC('month', mes.fecha)
            ) as esperado_mes,
            -- Detalle por semanas del mes
            (
              SELECT json_agg(
                json_build_object(
                  'semana', num_semana,
                  'fecha_inicio', inicio_semana,
                  'fecha_fin', fin_semana,
                  'monto', monto_semana
                ) ORDER BY num_semana
              )
              FROM (
                SELECT 
                  ROW_NUMBER() OVER (ORDER BY semana_inicio) as num_semana,
                  semana_inicio as inicio_semana,
                  LEAST(semana_inicio + 6, ultimo_dia_mes) as fin_semana,
                  (
                    SELECT COALESCE(SUM(monto_pagado), 0)
                    FROM public.pagos
                    WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE 
                      BETWEEN semana_inicio AND LEAST(semana_inicio + 6, ultimo_dia_mes)
                  ) as monto_semana
                FROM (
                  SELECT 
                    generate_series(
                      DATE_TRUNC('month', mes.fecha)::DATE,
                      (DATE_TRUNC('month', mes.fecha) + INTERVAL '1 month' - INTERVAL '1 day')::DATE,
                      '7 days'
                    )::DATE as semana_inicio,
                    (DATE_TRUNC('month', mes.fecha) + INTERVAL '1 month' - INTERVAL '1 day')::DATE as ultimo_dia_mes
                ) semanas_mes
              ) detalle_semanas
            ) as semanas_del_mes
          FROM (
            SELECT generate_series(
              v_fecha_inicio,
              v_fecha_hoy,
              '1 month'
            )::DATE as fecha
          ) mes
        ) datos_mes
      ) resultado_meses
    ),
    
    -- Estadísticas generales
    'estadisticas', json_build_object(
      'total_periodo', (
        SELECT COALESCE(SUM(monto_pagado), 0)
        FROM public.pagos
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE >= v_fecha_inicio
      ),
      'promedio_mensual', (
        SELECT ROUND(AVG(monto_mes), 2)
        FROM (
          SELECT 
            DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) as mes,
            SUM(monto_pagado) as monto_mes
          FROM public.pagos
          WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE >= v_fecha_inicio
          GROUP BY DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE)
        ) promedios
      ),
      'mejor_mes', (
        SELECT json_build_object(
          'año', EXTRACT(YEAR FROM mes)::INT,
          'mes', TO_CHAR(mes, 'TMMonth'),
          'monto', monto
        )
        FROM (
          SELECT 
            DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) as mes,
            SUM(monto_pagado) as monto
          FROM public.pagos
          WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE >= v_fecha_inicio
          GROUP BY DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE)
          ORDER BY monto DESC
          LIMIT 1
        ) mejor
      ),
      'tendencia', (
        -- Comparar último mes completo vs penúltimo
        SELECT CASE
          WHEN ultimo > penultimo THEN 'mejorando'
          WHEN ultimo < penultimo THEN 'bajando'
          ELSE 'estable'
        END
        FROM (
          SELECT 
            (
              SELECT COALESCE(SUM(monto_pagado), 0)
              FROM public.pagos
              WHERE DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = 
                    DATE_TRUNC('month', v_fecha_hoy - INTERVAL '1 month')
            ) as ultimo,
            (
              SELECT COALESCE(SUM(monto_pagado), 0)
              FROM public.pagos
              WHERE DATE_TRUNC('month', (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = 
                    DATE_TRUNC('month', v_fecha_hoy - INTERVAL '2 months')
            ) as penultimo
        ) comparacion
      )
    ),
    
    -- Comparativa año actual vs anterior
    'comparativa_anual', (
      SELECT json_build_object(
        'año_actual', EXTRACT(YEAR FROM v_fecha_hoy)::INT,
        'total_año_actual', (
          SELECT COALESCE(SUM(monto_pagado), 0)
          FROM public.pagos
          WHERE EXTRACT(YEAR FROM (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = EXTRACT(YEAR FROM v_fecha_hoy)
        ),
        'año_anterior', (EXTRACT(YEAR FROM v_fecha_hoy) - 1)::INT,
        'total_año_anterior', (
          SELECT COALESCE(SUM(monto_pagado), 0)
          FROM public.pagos
          WHERE EXTRACT(YEAR FROM (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = EXTRACT(YEAR FROM v_fecha_hoy) - 1
        ),
        'variacion_porcentual', (
          SELECT CASE
            WHEN año_anterior = 0 THEN NULL
            ELSE ROUND(((año_actual - año_anterior) * 100.0 / año_anterior), 1)
          END
          FROM (
            SELECT 
              (
                SELECT COALESCE(SUM(monto_pagado), 0)
                FROM public.pagos
                WHERE EXTRACT(YEAR FROM (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = EXTRACT(YEAR FROM v_fecha_hoy)
              ) as año_actual,
              (
                SELECT COALESCE(SUM(monto_pagado), 0)
                FROM public.pagos
                WHERE EXTRACT(YEAR FROM (fecha_pago AT TIME ZONE 'America/Lima')::DATE) = EXTRACT(YEAR FROM v_fecha_hoy) - 1
              ) as año_anterior
          ) datos
        )
      )
    )
  ) INTO v_resultado;
  
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_cobranza_por_mes"("p_numero_meses" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_cobranza_por_semana"("p_fecha_inicio" "date" DEFAULT NULL::"date", "p_numero_semanas" integer DEFAULT 4) RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_resultado JSON;
  v_fecha_base DATE;
  v_domingo_actual DATE;
BEGIN
  -- Si no se especifica fecha, usar HOY
  v_fecha_base := COALESCE(p_fecha_inicio, (NOW() AT TIME ZONE 'America/Lima')::DATE);
  
  -- Encontrar el domingo de la semana actual (fin de semana)
  v_domingo_actual := v_fecha_base + (6 - EXTRACT(DOW FROM v_fecha_base))::INTEGER;
  
  -- Construir el resultado
  SELECT json_build_object(
    -- Información de contexto
    'periodo_consultado', json_build_object(
      'fecha_inicio', v_domingo_actual - (p_numero_semanas * 7 - 1),
      'fecha_fin', v_domingo_actual,
      'numero_semanas', p_numero_semanas
    ),
    
    -- Detalle por semana
    'semanas', (
      SELECT json_agg(semana ORDER BY semana_inicio DESC)
      FROM (
        SELECT 
          json_build_object(
            'semana_numero', (p_numero_semanas - num_semana),
            'fecha_inicio', fecha_inicio_semana,
            'fecha_fin', fecha_fin_semana,
            'total_cobrado', total_semana,
            'clientes_pagaron', clientes_semana,
            'promedio_diario', ROUND(total_semana / 7, 2),
            'dias_con_cobro', dias_activos,
            'detalle_dias', dias_detalle
          ) as semana,
          fecha_inicio_semana as semana_inicio
        FROM (
          -- Para cada semana
          SELECT 
            num_semana,
            fecha_inicio_semana,
            fecha_fin_semana,
            COALESCE(SUM(monto_dia), 0) as total_semana,
            COUNT(DISTINCT CASE WHEN monto_dia > 0 THEN cliente_dia END) as clientes_semana,
            COUNT(CASE WHEN monto_dia > 0 THEN 1 END) as dias_activos,
            json_agg(
              json_build_object(
                'fecha', fecha_dia,
                'dia', TO_CHAR(fecha_dia, 'Dy'),
                'monto', monto_dia,
                'clientes', num_clientes_dia
              ) ORDER BY fecha_dia
            ) as dias_detalle
          FROM (
            -- Generar todas las fechas y sus cobros
            SELECT 
              num_semana,
              fecha_inicio_semana,
              fecha_fin_semana,
              dia.fecha as fecha_dia,
              COALESCE(SUM(p.monto_pagado), 0) as monto_dia,
              COUNT(DISTINCT p.cliente_id) as num_clientes_dia,
              p.cliente_id as cliente_dia
            FROM (
              -- Generar semanas
              SELECT 
                s.num as num_semana,
                v_domingo_actual - ((s.num * 7) - 1) as fecha_inicio_semana,
                v_domingo_actual - ((s.num - 1) * 7) as fecha_fin_semana
              FROM generate_series(0, p_numero_semanas - 1) s(num)
            ) semanas
            CROSS JOIN LATERAL (
              -- Generar días de cada semana
              SELECT generate_series(
                fecha_inicio_semana,
                fecha_fin_semana,
                '1 day'::interval
              )::date as fecha
            ) dia
            LEFT JOIN public.pagos p 
              ON (p.fecha_pago AT TIME ZONE 'America/Lima')::DATE = dia.fecha
            GROUP BY num_semana, fecha_inicio_semana, fecha_fin_semana, dia.fecha, p.cliente_id
          ) dias_semana
          GROUP BY num_semana, fecha_inicio_semana, fecha_fin_semana
        ) resumen_semanas
      ) resultado_final
    ),
    
    -- Comparativa entre semanas
    'comparativa', (
      SELECT json_build_object(
        'mejor_semana', (
          SELECT json_build_object(
            'fecha_inicio', fecha_inicio,
            'fecha_fin', fecha_fin,
            'monto', monto_total
          )
          FROM (
            SELECT 
              v_domingo_actual - ((s.num * 7) - 1) as fecha_inicio,
              v_domingo_actual - ((s.num - 1) * 7) as fecha_fin,
              COALESCE(SUM(p.monto_pagado), 0) as monto_total
            FROM generate_series(0, p_numero_semanas - 1) s(num)
            CROSS JOIN LATERAL (
              SELECT generate_series(
                v_domingo_actual - ((s.num * 7) - 1),
                v_domingo_actual - ((s.num - 1) * 7),
                '1 day'::interval
              )::date as fecha
            ) dias
            LEFT JOIN public.pagos p 
              ON (p.fecha_pago AT TIME ZONE 'America/Lima')::DATE = dias.fecha
            GROUP BY s.num
            ORDER BY monto_total DESC
            LIMIT 1
          ) mejor
        ),
        'promedio_semanal', (
          SELECT ROUND(AVG(monto_semanal), 2)
          FROM (
            SELECT COALESCE(SUM(p.monto_pagado), 0) as monto_semanal
            FROM generate_series(0, p_numero_semanas - 1) s(num)
            CROSS JOIN LATERAL (
              SELECT generate_series(
                v_domingo_actual - ((s.num * 7) - 1),
                v_domingo_actual - ((s.num - 1) * 7),
                '1 day'::interval
              )::date as fecha
            ) dias
            LEFT JOIN public.pagos p 
              ON (p.fecha_pago AT TIME ZONE 'America/Lima')::DATE = dias.fecha
            GROUP BY s.num
          ) promedios
        ),
        'tendencia', CASE
          -- Comparar última semana vs penúltima
          WHEN (
            SELECT COALESCE(SUM(monto_pagado), 0)
            FROM public.pagos
            WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE 
              BETWEEN v_domingo_actual - 6 AND v_domingo_actual
          ) > (
            SELECT COALESCE(SUM(monto_pagado), 0)
            FROM public.pagos
            WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE 
              BETWEEN v_domingo_actual - 13 AND v_domingo_actual - 7
          ) THEN 'mejorando'
          ELSE 'bajando'
        END
      )
    )
  ) INTO v_resultado;
  
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_cobranza_por_semana"("p_fecha_inicio" "date", "p_numero_semanas" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_estado_cartera_grafico"() RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  -- Variables para guardar los conteos
  v_al_dia INTEGER;          -- Cuántos están al día
  v_pendientes_hoy INTEGER;  -- Cuántos deben pagar hoy
  v_atrasados INTEGER;       -- Cuántos están morosos
  v_total_activos INTEGER;   -- Total de clientes activos
  v_resultado JSON;          -- El resultado final
BEGIN
  -- PASO 1: Contar clientes por estado
  -- Esta consulta cuenta cuántos clientes hay en cada estado
  SELECT 
    COUNT(*) FILTER (WHERE estado_real = 'al_dia'),      -- Cuenta los al día
    COUNT(*) FILTER (WHERE estado_real = 'pendiente'),   -- Cuenta los que pagan hoy
    COUNT(*) FILTER (WHERE estado_real = 'atrasado'),    -- Cuenta los morosos
    COUNT(*) FILTER (WHERE estado_real IN ('al_dia', 'pendiente', 'atrasado'))  -- Total activos
  INTO v_al_dia, v_pendientes_hoy, v_atrasados, v_total_activos
  FROM public.v_clientes_con_estado;  -- Usamos la vista que ya existe
  
  -- PASO 2: Construir el JSON de respuesta
  v_resultado := json_build_object(
    -- Array con los datos para el gráfico
    'datos_grafico', json_build_array(
      -- Primer segmento: Al día (Verde)
      json_build_object(
        'estado', 'Al día',
        'cantidad', v_al_dia,
        'porcentaje', CASE 
          WHEN v_total_activos = 0 THEN 0  -- Evita división por cero
          ELSE ROUND((v_al_dia * 100.0 / v_total_activos), 1)  -- Calcula %
        END,
        'color', '#4CAF50'  -- Verde
      ),
      -- Segundo segmento: Pagar hoy (Naranja)
      json_build_object(
        'estado', 'Pagar hoy',
        'cantidad', v_pendientes_hoy,
        'porcentaje', CASE 
          WHEN v_total_activos = 0 THEN 0 
          ELSE ROUND((v_pendientes_hoy * 100.0 / v_total_activos), 1)
        END,
        'color', '#FF9800'  -- Naranja
      ),
      -- Tercer segmento: Morosos (Rojo)
      json_build_object(
        'estado', 'Morosos',
        'cantidad', v_atrasados,
        'porcentaje', CASE 
          WHEN v_total_activos = 0 THEN 0 
          ELSE ROUND((v_atrasados * 100.0 / v_total_activos), 1)
        END,
        'color', '#F44336'  -- Rojo
      )
    ),
    -- Resumen adicional
    'resumen', json_build_object(
      'total_clientes_activos', v_total_activos,
      'requieren_atencion_hoy', v_pendientes_hoy + v_atrasados,  -- Suma urgentes
      'tasa_morosidad', CASE 
        WHEN v_total_activos = 0 THEN 0 
        ELSE ROUND((v_atrasados * 100.0 / v_total_activos), 1)
      END
    )
  );
  
  -- PASO 3: Devolver el resultado
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_estado_cartera_grafico"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_estado_del_dia"() RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_hoy DATE := (NOW() AT TIME ZONE 'America/Lima')::DATE;
  v_resultado JSON;
  v_pagaron_hoy INTEGER;
  v_solo_deben_hoy INTEGER;
  v_en_mora INTEGER;
  v_monto_cobrado_hoy NUMERIC;
BEGIN
  -- 1. Clientes que pagaron HOY (cualquier pago)
  SELECT COUNT(DISTINCT cliente_id)
  INTO v_pagaron_hoy
  FROM public.pagos
  WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE = v_hoy;
  
  -- 2. Clientes que SOLO deben la cuota de hoy (no tienen mora previa)
  SELECT COUNT(DISTINCT cr.cliente_id)
  INTO v_solo_deben_hoy
  FROM public.cronograma cr
  WHERE cr.fecha_venc = v_hoy
    AND cr.fecha_pagado IS NULL
    AND NOT EXISTS (
      -- No tiene cuotas anteriores sin pagar
      SELECT 1 FROM public.cronograma cr2
      WHERE cr2.cliente_id = cr.cliente_id
        AND cr2.fecha_venc < v_hoy
        AND cr2.fecha_pagado IS NULL
    );
  
  -- 3. Clientes en MORA (deben cuotas anteriores a hoy)
  SELECT COUNT(DISTINCT cliente_id)
  INTO v_en_mora
  FROM public.cronograma
  WHERE fecha_venc < v_hoy
    AND fecha_pagado IS NULL;
    
  -- 4. Total cobrado hoy
  SELECT COALESCE(SUM(monto_pagado), 0)
  INTO v_monto_cobrado_hoy
  FROM public.pagos
  WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE = v_hoy;
  
  -- Construir el JSON de respuesta
  SELECT json_build_object(
    'fecha_consulta', v_hoy,
    'dia_semana', TO_CHAR(v_hoy, 'TMDay'),
    
    -- Datos para el gráfico circular
    'grafico_del_dia', json_build_array(
      -- Pagaron hoy (Verde)
      json_build_object(
        'categoria', 'Pagaron hoy',
        'cantidad', v_pagaron_hoy,
        'porcentaje', CASE 
          WHEN (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora) = 0 THEN 0
          ELSE ROUND(v_pagaron_hoy * 100.0 / (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora), 1)
        END,
        'color', '#4CAF50',
        'descripcion', 'Clientes que realizaron algún pago hoy'
      ),
      
      -- Solo deben hoy (Naranja)
      json_build_object(
        'categoria', 'Pendiente solo hoy',
        'cantidad', v_solo_deben_hoy,
        'porcentaje', CASE 
          WHEN (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora) = 0 THEN 0
          ELSE ROUND(v_solo_deben_hoy * 100.0 / (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora), 1)
        END,
        'color', '#FF9800',
        'descripcion', 'Deben únicamente la cuota de hoy'
      ),
      
      -- En mora (Rojo)
      json_build_object(
        'categoria', 'En mora',
        'cantidad', v_en_mora,
        'porcentaje', CASE 
          WHEN (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora) = 0 THEN 0
          ELSE ROUND(v_en_mora * 100.0 / (v_pagaron_hoy + v_solo_deben_hoy + v_en_mora), 1)
        END,
        'color', '#F44336',
        'descripcion', 'Deben cuotas de días anteriores'
      )
    ),
    
    -- Resumen del día
    'resumen', json_build_object(
      'total_clientes_dia', v_pagaron_hoy + v_solo_deben_hoy + v_en_mora,
      'monto_cobrado_hoy', v_monto_cobrado_hoy,
      'clientes_por_cobrar', v_solo_deben_hoy + v_en_mora,
      'requieren_atencion_urgente', v_en_mora
    ),
    
    -- Detalle de mora
    'detalle_mora', (
      SELECT json_build_object(
        'total_clientes_morosos', COUNT(DISTINCT cliente_id),
        'total_cuotas_vencidas', COUNT(*),
        'monto_total_vencido', COALESCE(SUM(monto_cuota), 0),
        'promedio_dias_atraso', ROUND(AVG(v_hoy - fecha_venc), 1)
      )
      FROM public.cronograma
      WHERE fecha_venc < v_hoy
        AND fecha_pagado IS NULL
    )
  ) INTO v_resultado;
  
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_estado_del_dia"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_reporte_completo"() RETURNS "json"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_resultado JSON;
  v_fecha_hoy DATE := (NOW() AT TIME ZONE 'America/Lima')::DATE;
  v_inicio_mes DATE := DATE_TRUNC('month', v_fecha_hoy);
BEGIN
  -- Construir JSON con todos los datos del reporte
  SELECT json_build_object(
    -- =====================================================
    -- RESUMEN DEL DÍA DE HOY
    -- =====================================================
    'resumen_hoy', json_build_object(
      'cobrado_hoy', (
        SELECT COALESCE(SUM(monto_pagado), 0)::numeric(10,2)
        FROM public.pagos 
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE = v_fecha_hoy
      ),
      'clientes_pagaron_hoy', (
        SELECT COUNT(DISTINCT cliente_id)::integer
        FROM public.pagos 
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE = v_fecha_hoy
      ),
      'gastos_hoy', 0::numeric(10,2),
      'balance_hoy', (
        SELECT COALESCE(SUM(monto_pagado), 0)::numeric(10,2)
        FROM public.pagos 
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE = v_fecha_hoy
      )
    ),
    
    -- =====================================================
    -- ESTADO DE CARTERA (reutilizamos la lógica anterior)
    -- =====================================================
    'estado_cartera', (
      SELECT json_build_object(
        'al_dia', COUNT(*) FILTER (WHERE estado_real = 'al_dia'),
        'pendientes_hoy', COUNT(*) FILTER (WHERE estado_real = 'pendiente'),
        'atrasados', COUNT(*) FILTER (WHERE estado_real = 'atrasado'),
        'completados', COUNT(*) FILTER (WHERE estado_real = 'completo'),
        'total_activos', COUNT(*) FILTER (WHERE estado_real != 'completo'),
        'saldo_total_pendiente', (
          SELECT COALESCE(SUM(saldo_pendiente), 0)::numeric(10,2)
          FROM public.clientes
          WHERE estado_pago != 'completo'
        )
      )
      FROM public.v_clientes_con_estado
    ),
    
    -- =====================================================
    -- COBRANZA DE LOS ÚLTIMOS 7 DÍAS
    -- =====================================================
    'cobranza_semanal', (
      SELECT json_agg(
        json_build_object(
          'fecha', dia.fecha,
          'dia_nombre', dia.dia_nombre,
          'dia_corto', dia.dia_corto,
          'monto', dia.monto,
          'cantidad_pagos', dia.cantidad_pagos
        ) ORDER BY dia.fecha
      )
      FROM (
        SELECT 
          fechas.fecha,
          TO_CHAR(fechas.fecha, 'TMDay') as dia_nombre,
          TO_CHAR(fechas.fecha, 'Dy') as dia_corto,
          COALESCE(SUM(p.monto_pagado), 0)::numeric(10,2) as monto,
          COUNT(p.id)::integer as cantidad_pagos
        FROM (
          -- Genera las últimas 7 fechas
          SELECT generate_series(
            v_fecha_hoy - INTERVAL '6 days',
            v_fecha_hoy,
            '1 day'::interval
          )::date as fecha
        ) fechas
        LEFT JOIN public.pagos p 
          ON (p.fecha_pago AT TIME ZONE 'America/Lima')::DATE = fechas.fecha
        GROUP BY fechas.fecha
      ) dia
    ),
    
    -- =====================================================
    -- GASTOS (placeholder por ahora)
    -- =====================================================
    'gastos_categoria', json_build_object(
      'Gasolina', 0::numeric(10,2),
      'Teléfono', 0::numeric(10,2),
      'Comida', 0::numeric(10,2),
      'Otro', 0::numeric(10,2),
      'total', 0::numeric(10,2)
    ),
    
    -- =====================================================
    -- KPIs DEL MES ACTUAL
    -- =====================================================
    'kpis_mes', json_build_object(
      'nuevos_creditos', (
        SELECT COUNT(*)::integer
        FROM public.clientes 
        WHERE (fecha_creacion AT TIME ZONE 'America/Lima')::DATE >= v_inicio_mes
      ),
      'creditos_cerrados', (
        SELECT COUNT(*)::integer
        FROM public.cliente_historial
        WHERE (fecha_cierre AT TIME ZONE 'America/Lima')::DATE >= v_inicio_mes
      ),
      'tasa_morosidad', (
        SELECT CASE 
          WHEN COUNT(*) = 0 THEN 0
          ELSE ROUND(
            COUNT(*) FILTER (WHERE estado_real = 'atrasado') * 100.0 / 
            COUNT(*) FILTER (WHERE estado_real != 'completo'), 
            1
          )
        END
        FROM public.v_clientes_con_estado
      ),
      'total_prestado_mes', (
        SELECT COALESCE(SUM(monto_solicitado), 0)::numeric(10,2)
        FROM public.clientes
        WHERE (fecha_creacion AT TIME ZONE 'America/Lima')::DATE >= v_inicio_mes
      ),
      'total_cobrado_mes', (
        SELECT COALESCE(SUM(monto_pagado), 0)::numeric(10,2)
        FROM public.pagos
        WHERE (fecha_pago AT TIME ZONE 'America/Lima')::DATE >= v_inicio_mes
      )
    ),
    
    -- =====================================================
    -- INFORMACIÓN ADICIONAL
    -- =====================================================
    'metadata', json_build_object(
      'fecha_generacion', NOW(),
      'zona_horaria', 'America/Lima',
      'fecha_reporte', v_fecha_hoy
    )
    
  ) INTO v_resultado;
  
  RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_reporte_completo"() OWNER TO "postgres";


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
    "fecha_inicio" "date",
    "latitud_cierre" double precision,
    "longitud_cierre" double precision,
    "direccion_cierre" "text"
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
    "fecha_primer_pago" "date",
    "latitud" double precision,
    "longitud" double precision
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



CREATE TABLE IF NOT EXISTS "public"."gastos" (
    "id" bigint NOT NULL,
    "usuario_id" "text" DEFAULT ("auth"."uid"())::"text" NOT NULL,
    "fecha_gasto" "date" DEFAULT (("now"() AT TIME ZONE 'America/Lima'::"text"))::"date" NOT NULL,
    "categoria" "text" NOT NULL,
    "monto" numeric NOT NULL,
    "descripcion" "text",
    "foto_url" "text",
    "latitud" double precision,
    "longitud" double precision,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "gastos_categoria_check" CHECK (("categoria" = ANY (ARRAY['Gasolina'::"text", 'Teléfono'::"text", 'Comida'::"text", 'Otro'::"text"]))),
    CONSTRAINT "gastos_monto_check" CHECK (("monto" > (0)::numeric))
);


ALTER TABLE "public"."gastos" OWNER TO "postgres";


ALTER TABLE "public"."gastos" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."gastos_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



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
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "latitud" double precision,
    "longitud" double precision,
    "direccion_cobro" "text"
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
    "cli"."latitud",
    "cli"."longitud",
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


CREATE OR REPLACE VIEW "public"."v_gastos_por_categoria" AS
 SELECT "gastos"."categoria",
    "sum"("gastos"."monto") AS "total_categoria",
    "count"(*) AS "cantidad",
    "avg"("gastos"."monto") AS "promedio",
    "min"("gastos"."fecha_gasto") AS "primer_gasto",
    "max"("gastos"."fecha_gasto") AS "ultimo_gasto"
   FROM "public"."gastos"
  GROUP BY "gastos"."categoria";


ALTER TABLE "public"."v_gastos_por_categoria" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_gastos_resumen" AS
 SELECT "gastos"."usuario_id",
    "gastos"."fecha_gasto" AS "fecha",
    "gastos"."categoria",
    "sum"("gastos"."monto") AS "total_dia",
    "count"(*) AS "cantidad_gastos",
    "avg"("gastos"."monto") AS "promedio_gasto"
   FROM "public"."gastos"
  GROUP BY "gastos"."usuario_id", "gastos"."fecha_gasto", "gastos"."categoria"
  ORDER BY "gastos"."fecha_gasto" DESC;


ALTER TABLE "public"."v_gastos_resumen" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_pagos_con_ubicacion" AS
 SELECT "p"."id",
    "p"."cliente_id",
    "p"."numero_cuota",
    "p"."monto_pagado",
    "p"."fecha_pago",
    "p"."created_at",
    "p"."latitud",
    "p"."longitud",
    "p"."direccion_cobro",
    "c"."nombre" AS "cliente_nombre",
    "c"."direccion" AS "cliente_direccion",
        CASE
            WHEN ("p"."latitud" IS NOT NULL) THEN "format"('%.6f, %.6f'::"text", "p"."latitud", "p"."longitud")
            ELSE 'Sin ubicación'::"text"
        END AS "coordenadas"
   FROM ("public"."pagos" "p"
     JOIN "public"."clientes" "c" ON (("c"."id" = "p"."cliente_id")))
  ORDER BY "p"."fecha_pago" DESC;


ALTER TABLE "public"."v_pagos_con_ubicacion" OWNER TO "postgres";


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



ALTER TABLE ONLY "public"."gastos"
    ADD CONSTRAINT "gastos_pkey" PRIMARY KEY ("id");



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



CREATE OR REPLACE TRIGGER "trg_log_gasto" AFTER INSERT ON "public"."gastos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_log_gasto"();



CREATE OR REPLACE TRIGGER "trg_log_pago" AFTER INSERT ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_log_pago"();



CREATE OR REPLACE TRIGGER "trg_pagos_aiud" AFTER INSERT OR DELETE ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_actualizar_estado"();



CREATE OR REPLACE TRIGGER "trg_pagos_cierre" AFTER INSERT ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."_trigger_cierre_historial"();



CREATE OR REPLACE TRIGGER "trg_refinanciar_cliente" AFTER UPDATE OF "monto_solicitado", "plazo_dias", "fecha_primer_pago" ON "public"."clientes" FOR EACH ROW WHEN ((("old"."monto_solicitado" IS DISTINCT FROM "new"."monto_solicitado") OR ("old"."plazo_dias" IS DISTINCT FROM "new"."plazo_dias") OR ("old"."fecha_primer_pago" IS DISTINCT FROM "new"."fecha_primer_pago"))) EXECUTE FUNCTION "public"."_trigger_refinanciar_cliente"();



CREATE OR REPLACE TRIGGER "trg_validar_gasto" BEFORE INSERT OR UPDATE ON "public"."gastos" FOR EACH ROW EXECUTE FUNCTION "public"."_validar_gasto"();



ALTER TABLE ONLY "public"."cliente_historial"
    ADD CONSTRAINT "cliente_historial_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cronograma"
    ADD CONSTRAINT "cronograma_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."historial_eventos"
    ADD CONSTRAINT "historial_eventos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



CREATE POLICY "Usuarios pueden actualizar sus propios gastos" ON "public"."gastos" FOR UPDATE TO "authenticated" USING ((("auth"."uid"())::"text" = "usuario_id")) WITH CHECK ((("auth"."uid"())::"text" = "usuario_id"));



CREATE POLICY "Usuarios pueden crear sus propios gastos" ON "public"."gastos" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"())::"text" = "usuario_id"));



CREATE POLICY "Usuarios pueden eliminar sus propios gastos" ON "public"."gastos" FOR DELETE TO "authenticated" USING ((("auth"."uid"())::"text" = "usuario_id"));



CREATE POLICY "Usuarios ven sus propios gastos" ON "public"."gastos" USING ((("auth"."uid"())::"text" = "usuario_id"));





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



GRANT ALL ON FUNCTION "public"."_trigger_log_gasto"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_log_gasto"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_log_gasto"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_log_pago"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_refinanciar_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "anon";
GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_trigger_regenerar_cronograma"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_validar_gasto"() TO "anon";
GRANT ALL ON FUNCTION "public"."_validar_gasto"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_validar_gasto"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_validar_recalcular_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."_validar_y_recalcular_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito_con_ubicacion"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date", "p_latitud" double precision, "p_longitud" double precision, "p_direccion" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito_con_ubicacion"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date", "p_latitud" double precision, "p_longitud" double precision, "p_direccion" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."abrir_nuevo_credito_con_ubicacion"("p_cliente_id" bigint, "p_monto_solicitado" numeric, "p_plazo_dias" integer, "p_fecha_primer_pago" "date", "p_latitud" double precision, "p_longitud" double precision, "p_direccion" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_estado_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_saldo_cliente"() TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_cronograma_para_cliente"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado"("p_cliente_id" bigint, "p_monto_orig" numeric, "p_fecha_inicio" "date", "p_plazo_dias" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_historial_cerrado_v1"("p_cliente_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_dias"("p_dias_atras" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_dias"("p_dias_atras" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_dias"("p_dias_atras" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_mes"("p_numero_meses" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_mes"("p_numero_meses" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_mes"("p_numero_meses" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_semana"("p_fecha_inicio" "date", "p_numero_semanas" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_semana"("p_fecha_inicio" "date", "p_numero_semanas" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_cobranza_por_semana"("p_fecha_inicio" "date", "p_numero_semanas" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_estado_cartera_grafico"() TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_estado_cartera_grafico"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_estado_cartera_grafico"() TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_estado_del_dia"() TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_estado_del_dia"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_estado_del_dia"() TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_reporte_completo"() TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_reporte_completo"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_reporte_completo"() TO "service_role";



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



GRANT ALL ON TABLE "public"."gastos" TO "anon";
GRANT ALL ON TABLE "public"."gastos" TO "authenticated";
GRANT ALL ON TABLE "public"."gastos" TO "service_role";



GRANT ALL ON SEQUENCE "public"."gastos_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."gastos_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."gastos_id_seq" TO "service_role";



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



GRANT ALL ON TABLE "public"."v_gastos_por_categoria" TO "anon";
GRANT ALL ON TABLE "public"."v_gastos_por_categoria" TO "authenticated";
GRANT ALL ON TABLE "public"."v_gastos_por_categoria" TO "service_role";



GRANT ALL ON TABLE "public"."v_gastos_resumen" TO "anon";
GRANT ALL ON TABLE "public"."v_gastos_resumen" TO "authenticated";
GRANT ALL ON TABLE "public"."v_gastos_resumen" TO "service_role";



GRANT ALL ON TABLE "public"."v_pagos_con_ubicacion" TO "anon";
GRANT ALL ON TABLE "public"."v_pagos_con_ubicacion" TO "authenticated";
GRANT ALL ON TABLE "public"."v_pagos_con_ubicacion" TO "service_role";









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
