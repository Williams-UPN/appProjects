-- ==========================================================
-- LIMPIEZA: eliminar triggers, funciones y tablas antiguas
-- ==========================================================
DROP TRIGGER IF EXISTS trg_clientes_bi  ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_ai  ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_bu  ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_au  ON public.clientes;
DROP TRIGGER IF EXISTS trg_pagos_aiud   ON public.pagos;

DROP FUNCTION IF EXISTS public._validar_y_recalcular_cliente() CASCADE;
DROP FUNCTION IF EXISTS public._validar_y_recalcular_cliente_upd() CASCADE;
DROP FUNCTION IF EXISTS public._crear_cronograma_aux(bigint) CASCADE;
DROP FUNCTION IF EXISTS public._trigger_generar_cronograma() CASCADE;
DROP FUNCTION IF EXISTS public._trigger_regenerar_cronograma() CASCADE;
DROP FUNCTION IF EXISTS public._trigger_actualizar_estado() CASCADE;

DROP TABLE IF EXISTS public.pagos      CASCADE;
DROP TABLE IF EXISTS public.cronograma CASCADE;
DROP TABLE IF EXISTS public.clientes   CASCADE;


-- ==========================================================
-- 1. TABLAS
-- ==========================================================
CREATE TABLE public.clientes (
  id                BIGSERIAL PRIMARY KEY,
  nombre            TEXT    NOT NULL,
  telefono          TEXT    NOT NULL,
  direccion         TEXT    NOT NULL,
  negocio           TEXT,
  monto_solicitado  NUMERIC NOT NULL DEFAULT 0,
  plazo_dias        INTEGER NOT NULL DEFAULT 0,
  fecha_creacion    TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_primer_pago TIMESTAMPTZ NOT NULL,
  fecha_final       TIMESTAMPTZ NOT NULL,
  total_pagar       NUMERIC NOT NULL DEFAULT 0,
  cuota_diaria      NUMERIC NOT NULL DEFAULT 0,
  ultima_cuota      NUMERIC NOT NULL DEFAULT 0,
  saldo_pendiente   NUMERIC NOT NULL DEFAULT 0,
  dias_atraso       INTEGER NOT NULL DEFAULT 0,
  estado_pago       TEXT    NOT NULL DEFAULT 'al_dia',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.cronograma (
  id              BIGSERIAL PRIMARY KEY,
  cliente_id      BIGINT   NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  numero_cuota    INTEGER  NOT NULL,
  fecha_venc      DATE     NOT NULL,
  monto_cuota     NUMERIC  NOT NULL,
  fecha_pagado    DATE,
  CONSTRAINT cronograma_unico UNIQUE (cliente_id, numero_cuota)
);

CREATE TABLE public.pagos (
  id            BIGSERIAL PRIMARY KEY,
  cliente_id    BIGINT   NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  numero_cuota  INTEGER  NOT NULL,
  monto_pagado  NUMERIC  NOT NULL,
  fecha_pago    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pagos_unicos_por_cuota UNIQUE (cliente_id, numero_cuota)
);


-- ==========================================================
-- 2. Función auxiliar: crear cronograma para un cliente dado
-- ==========================================================
CREATE OR REPLACE FUNCTION public._crear_cronograma_aux(p_cliente_id BIGINT)
RETURNS void LANGUAGE plpgsql AS $$
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
    INSERT INTO public.cronograma(cliente_id, numero_cuota, fecha_venc, monto_cuota)
    VALUES (
      p_cliente_id,
      i,
      v_fecha_inicio + (i-1) * INTERVAL '1 day',
      CASE WHEN i = v_plazo THEN v_last ELSE v_std END
    );
  END LOOP;
END;
$$;


-- ==========================================================
-- 3. BEFORE INSERT: validar y recalcular montos + fechas
-- ==========================================================
CREATE OR REPLACE FUNCTION public._validar_y_recalcular_cliente()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_tasa         NUMERIC;
  v_total        NUMERIC;
  v_std          NUMERIC;
  v_last         NUMERIC;
  v_fp_peru_date DATE;
  v_today        DATE := (now() AT TIME ZONE 'America/Lima')::date;
BEGIN
  -- Validar monto y plazo
  IF NEW.monto_solicitado <= 0 THEN
    RAISE EXCEPTION 'monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
  ELSIF NEW.plazo_dias NOT IN (12,24) THEN
    RAISE EXCEPTION 'plazo_dias (%) inválido', NEW.plazo_dias;
  END IF;

  -- Validar fecha_primer_pago ≥ hoy (Lima)
  v_fp_peru_date := (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date;
  IF v_fp_peru_date < v_today THEN
    RAISE EXCEPTION 'fecha_primer_pago (%) debe ser ≥ hoy (Lima: %)', NEW.fecha_primer_pago, v_today;
  END IF;

  -- Calcular totales y cuotas
  v_tasa  := CASE WHEN NEW.plazo_dias = 12 THEN 10 ELSE 20 END;
  v_total := NEW.monto_solicitado * (1 + v_tasa/100);
  v_std   := ceil(v_total / NEW.plazo_dias);
  v_last  := v_total - v_std * (NEW.plazo_dias - 1);

  NEW.total_pagar  := v_total;
  NEW.cuota_diaria := v_std;
  NEW.ultima_cuota := v_last;
  NEW.fecha_final  := (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date
                      + (NEW.plazo_dias - 1) * INTERVAL '1 day';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_clientes_bi ON public.clientes;
CREATE TRIGGER trg_clientes_bi
  BEFORE INSERT ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._validar_y_recalcular_cliente();


-- ==========================================================
-- 4. BEFORE UPDATE: validar y recalcular si cambian términos
-- ==========================================================
CREATE OR REPLACE FUNCTION public._validar_y_recalcular_cliente_upd()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.monto_solicitado   <> OLD.monto_solicitado
     OR NEW.plazo_dias       <> OLD.plazo_dias
     OR NEW.fecha_primer_pago <> OLD.fecha_primer_pago
  THEN
    RETURN public._validar_y_recalcular_cliente();
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_clientes_bu
  BEFORE UPDATE ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._validar_y_recalcular_cliente_upd();


-- ==========================================================
-- 5. AFTER INSERT: generar cronograma + estado inicial
-- ==========================================================
CREATE OR REPLACE FUNCTION public._trigger_generar_cronograma()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_hoy    DATE := (now() AT TIME ZONE 'America/Lima')::date;
  v_estado TEXT;
BEGIN
  PERFORM public._crear_cronograma_aux(NEW.id);

  UPDATE public.clientes
     SET saldo_pendiente = NEW.total_pagar
   WHERE id = NEW.id;

  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.cronograma
       WHERE cliente_id = NEW.id
         AND fecha_venc = v_hoy
         AND fecha_pagado IS NULL
    ) THEN 'pendiente'
    ELSE 'al_dia'
  END INTO v_estado;

  UPDATE public.clientes
     SET estado_pago = v_estado
   WHERE id = NEW.id;

  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_clientes_ai
  AFTER INSERT ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_generar_cronograma();


-- ==========================================================
-- 6. AFTER UPDATE: regenerar cronograma si cambian términos
-- ==========================================================
CREATE OR REPLACE FUNCTION public._trigger_regenerar_cronograma()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.monto_solicitado   <> NEW.monto_solicitado
     OR OLD.plazo_dias        <> NEW.plazo_dias
     OR OLD.fecha_primer_pago <> NEW.fecha_primer_pago
  THEN
    DELETE FROM public.cronograma
     WHERE cliente_id = NEW.id;
    PERFORM public._crear_cronograma_aux(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_clientes_au
  AFTER UPDATE ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_regenerar_cronograma();


-- ==========================================================
-- 7. AFTER INSERT/DELETE en pagos: actualizar estado general
-- ==========================================================
CREATE OR REPLACE FUNCTION public._trigger_actualizar_estado()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  cid             BIGINT := COALESCE(NEW.cliente_id, OLD.cliente_id);
  v_hoy           DATE   := (now() AT TIME ZONE 'America/Lima')::date;
  cuotas_vencidas INTEGER;
  cuota_hoy_pend  BOOLEAN;
  todas_pagadas   BOOLEAN;
  ultima_pagada   INTEGER;
  total_pagado    NUMERIC;
  est_final       TEXT;
BEGIN
  -- Ajustar fecha_pagado en cronograma
  IF TG_OP = 'INSERT' THEN
    UPDATE public.cronograma
       SET fecha_pagado = (NEW.fecha_pago AT TIME ZONE 'America/Lima')::date
     WHERE cliente_id = cid
       AND numero_cuota = NEW.numero_cuota;
  ELSE
    UPDATE public.cronograma
       SET fecha_pagado = NULL
     WHERE cliente_id = cid
       AND numero_cuota = OLD.numero_cuota;
  END IF;

  -- Calcular atrasos
  SELECT COUNT(*) INTO cuotas_vencidas
    FROM public.cronograma
   WHERE cliente_id = cid
     AND fecha_venc < v_hoy
     AND fecha_pagado IS NULL;

  -- ¿Pendiente hoy?
  SELECT EXISTS(
    SELECT 1 FROM public.cronograma
     WHERE cliente_id = cid
       AND fecha_venc = v_hoy
       AND fecha_pagado IS NULL
  ) INTO cuota_hoy_pend;

  -- ¿Todas pagadas?
  SELECT NOT EXISTS(
    SELECT 1 FROM public.cronograma
     WHERE cliente_id = cid
       AND fecha_pagado IS NULL
  ) INTO todas_pagadas;

  -- Última cuota pagada
  SELECT COALESCE(MAX(numero_cuota),0) INTO ultima_pagada
    FROM public.cronograma
   WHERE cliente_id = cid
     AND fecha_pagado IS NOT NULL;

  -- Total pagado
  SELECT COALESCE(SUM(monto_pagado),0) INTO total_pagado
    FROM public.pagos
   WHERE cliente_id = cid;

  -- Determinar estado final
  est_final := CASE
    WHEN todas_pagadas        THEN 'completo'
    WHEN cuotas_vencidas > 0  THEN 'atrasado'
    WHEN cuota_hoy_pend       THEN 'pendiente'
    ELSE 'al_dia'
  END;

  -- Actualizar cliente
  UPDATE public.clientes
     SET estado_pago     = est_final,
         dias_atraso     = cuotas_vencidas,
         ultima_cuota    = ultima_pagada,
         saldo_pendiente = total_pagar - total_pagado
   WHERE id = cid;

  RETURN COALESCE(NEW,OLD);
END;
$$;
CREATE TRIGGER trg_pagos_aiud
  AFTER INSERT OR DELETE ON public.pagos
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_actualizar_estado();


-- ==========================================================
-- 8. (Opcional) Deshabilitar RLS mientras pruebas
-- ==========================================================
ALTER TABLE public.clientes   DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos      DISABLE ROW LEVEL SECURITY;
