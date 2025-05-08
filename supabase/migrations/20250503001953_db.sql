-- ==========================================================
-- LIMPIEZA: eliminar triggers, funciones y tablas antiguas
-- ==========================================================
DROP TRIGGER IF EXISTS trg_clientes_bi       ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_ai       ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_bu       ON public.clientes;
DROP TRIGGER IF EXISTS trg_clientes_au       ON public.clientes;
DROP TRIGGER IF EXISTS trg_pagos_aiud        ON public.pagos;
DROP TRIGGER IF EXISTS trg_pagos_cierre      ON public.pagos;

DROP FUNCTION IF EXISTS public._validar_y_recalcular_cliente()            CASCADE;
DROP FUNCTION IF EXISTS public._validar_y_recalcular_cliente_upd()        CASCADE;
DROP FUNCTION IF EXISTS public._crear_cronograma_aux(bigint)             CASCADE;
DROP FUNCTION IF EXISTS public._trigger_generar_cronograma()             CASCADE;
DROP FUNCTION IF EXISTS public._trigger_regenerar_cronograma()           CASCADE;
DROP FUNCTION IF EXISTS public._trigger_actualizar_estado()              CASCADE;
DROP FUNCTION IF EXISTS public._trigger_cierre_historial()               CASCADE;
DROP FUNCTION IF EXISTS public.crear_historial_cerrado(bigint)           CASCADE;

DROP TABLE IF EXISTS public.pagos            CASCADE;
DROP TABLE IF EXISTS public.cronograma       CASCADE;
DROP TABLE IF EXISTS public.clientes         CASCADE;
DROP TABLE IF EXISTS public.historial_eventos CASCADE;
DROP TABLE IF EXISTS public.cliente_historial CASCADE;

-- ==========================================================
-- 1. TABLAS
-- ==========================================================
CREATE TABLE public.clientes (
  id                     BIGSERIAL PRIMARY KEY,
  nombre                 TEXT        NOT NULL,
  telefono               TEXT        NOT NULL,
  direccion              TEXT        NOT NULL,
  negocio                TEXT,
  monto_solicitado       NUMERIC     NOT NULL DEFAULT 0,
  plazo_dias             INTEGER     NOT NULL DEFAULT 0,
  fecha_creacion         TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_primer_pago      TIMESTAMPTZ NOT NULL,
  fecha_final            TIMESTAMPTZ NOT NULL,
  total_pagar            NUMERIC     NOT NULL DEFAULT 0,
  cuota_diaria           NUMERIC     NOT NULL DEFAULT 0,
  ultima_cuota           NUMERIC     NOT NULL DEFAULT 0,
  saldo_pendiente        NUMERIC     NOT NULL DEFAULT 0,
  dias_atraso            INTEGER     NOT NULL DEFAULT 0,
  estado_pago            TEXT        NOT NULL DEFAULT 'al_dia',
  ultima_cuota_numero    INTEGER     NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.cronograma (
  id            BIGSERIAL PRIMARY KEY,
  cliente_id    BIGINT     NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  numero_cuota  INTEGER    NOT NULL,
  fecha_venc    DATE       NOT NULL,
  monto_cuota   NUMERIC    NOT NULL,
  fecha_pagado  DATE,
  CONSTRAINT cronograma_unico UNIQUE (cliente_id, numero_cuota)
);

CREATE TABLE public.pagos (
  id             BIGSERIAL PRIMARY KEY,
  cliente_id     BIGINT     NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  numero_cuota   INTEGER    NOT NULL,
  monto_pagado   NUMERIC    NOT NULL,
  fecha_pago     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pagos_unicos_por_cuota UNIQUE (cliente_id, numero_cuota)
);

CREATE TABLE public.historial_eventos (
  id            BIGSERIAL PRIMARY KEY,
  cliente_id    BIGINT     NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  fecha_evento  TIMESTAMPTZ NOT NULL DEFAULT now(),
  tipo_evento   TEXT        NOT NULL DEFAULT 'Incidencia',
  descripcion   TEXT
);

CREATE TABLE public.cliente_historial (
  id               BIGSERIAL PRIMARY KEY,
  cliente_id       BIGINT     NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  fecha_cierre     TIMESTAMPTZ NOT NULL,
  monto_solicitado NUMERIC     NOT NULL,
  total_pagado     NUMERIC     NOT NULL,
  dias_totales     INTEGER     NOT NULL,
  dias_atraso_max  INTEGER     NOT NULL,
  incidencias      INTEGER     NOT NULL DEFAULT 0,
  observaciones    TEXT,
  calificacion     INTEGER     NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================
-- 2. Función auxiliar: crear cronograma para un cliente dado
-- ==========================================================
CREATE OR REPLACE FUNCTION public._crear_cronograma_aux(p_cliente_id BIGINT)
  RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_plazo       INTEGER;
  v_std         NUMERIC;
  v_last        NUMERIC;
  v_fecha_inicio DATE;
  i             INTEGER;
BEGIN
  SELECT
    plazo_dias,
    cuota_diaria,
    ultima_cuota,
    fecha_primer_pago::date
  INTO
    v_plazo, v_std, v_last, v_fecha_inicio
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

-- ==========================================================
-- 3. BEFORE INSERT: validar y recalcular montos + fechas
-- ==========================================================
CREATE OR REPLACE FUNCTION public._validar_y_recalcular_cliente()
  RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_tasa          NUMERIC;
  v_total         NUMERIC;
  v_std           NUMERIC;
  v_last          NUMERIC;
  v_fp_peru_date  DATE;
  v_today         DATE := (now() AT TIME ZONE 'America/Lima')::date;
BEGIN
  IF NEW.monto_solicitado <= 0 THEN
    RAISE EXCEPTION 'monto_solicitado (%) debe ser > 0', NEW.monto_solicitado;
  ELSIF NEW.plazo_dias NOT IN (12, 24) THEN
    RAISE EXCEPTION 'plazo_dias (%) inválido', NEW.plazo_dias;
  END IF;

  v_fp_peru_date := (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date;
  IF v_fp_peru_date < v_today THEN
    RAISE EXCEPTION 'fecha_primer_pago (%) debe ser ≥ hoy (Lima: %)', NEW.fecha_primer_pago, v_today;
  END IF;

  v_tasa   := CASE WHEN NEW.plazo_dias = 12 THEN 10 ELSE 20 END;
  v_total  := NEW.monto_solicitado * (1 + v_tasa / 100);
  v_std    := ceil(v_total / NEW.plazo_dias);
  v_last   := v_total - v_std * (NEW.plazo_dias - 1);

  NEW.total_pagar       := v_total;
  NEW.cuota_diaria      := v_std;
  NEW.ultima_cuota      := v_last;
  NEW.fecha_final       := ((NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date 
                             + (NEW.plazo_dias - 1) * INTERVAL '1 day');
  NEW.ultima_cuota_numero := 0;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_clientes_bi
  BEFORE INSERT ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._validar_y_recalcular_cliente();

-- ==========================================================
-- 4. BEFORE UPDATE: validar y recalcular si cambian términos
-- ==========================================================
CREATE OR REPLACE FUNCTION public._validar_y_recalcular_cliente_upd()
  RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.monto_solicitado <> OLD.monto_solicitado
     OR NEW.plazo_dias       <> OLD.plazo_dias
     OR NEW.fecha_primer_pago<> OLD.fecha_primer_pago THEN
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
  v_hoy DATE := (now() AT TIME ZONE 'America/Lima')::date;
  v_fp  DATE := (NEW.fecha_primer_pago AT TIME ZONE 'America/Lima')::date;
  v_estado TEXT;
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

CREATE TRIGGER trg_clientes_ai
  AFTER INSERT ON public.clientes
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_generar_cronograma();

-- ==========================================================
-- 6. AFTER UPDATE: regenerar cronograma si cambian términos
-- ==========================================================
CREATE OR REPLACE FUNCTION public._trigger_regenerar_cronograma()
  RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.monto_solicitado <> NEW.monto_solicitado
     OR OLD.plazo_dias       <> NEW.plazo_dias
     OR OLD.fecha_primer_pago<> NEW.fecha_primer_pago THEN
    DELETE FROM public.cronograma WHERE cliente_id = NEW.id;
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
  cid               BIGINT := COALESCE(NEW.cliente_id, OLD.cliente_id);
  v_hoy             DATE   := (now() AT TIME ZONE 'America/Lima')::date;
  v_fp              DATE;
  cuotas_vencidas   INTEGER;
  cuota_hoy_pend    BOOLEAN;
  todas_pagadas     BOOLEAN;
  ultima_pag_num    INTEGER;
  total_pagado      NUMERIC;
  est_final         TEXT;
BEGIN
  -- marca/desmarca en cronograma
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

  -- datos de cliente
  SELECT (fecha_primer_pago AT TIME ZONE 'America/Lima')::date
    INTO v_fp
    FROM public.clientes
   WHERE id = cid;

  -- cálculos de atrasos y pagos
  SELECT COUNT(*) INTO cuotas_vencidas
    FROM public.cronograma
   WHERE cliente_id = cid
     AND fecha_venc < v_hoy
     AND fecha_pagado IS NULL;

  SELECT EXISTS(
    SELECT 1 FROM public.cronograma
     WHERE cliente_id = cid
       AND fecha_venc = v_hoy
       AND fecha_pagado IS NULL
  ) INTO cuota_hoy_pend;

  SELECT NOT EXISTS(
    SELECT 1 FROM public.cronograma
     WHERE cliente_id = cid
       AND fecha_pagado IS NULL
  ) INTO todas_pagadas;

  SELECT COALESCE(MAX(numero_cuota), 0) INTO ultima_pag_num
    FROM public.cronograma
   WHERE cliente_id = cid
     AND fecha_pagado IS NOT NULL;

  SELECT COALESCE(SUM(monto_pagado), 0) INTO total_pagado
    FROM public.pagos
   WHERE cliente_id = cid;

  -- estado final
  IF v_fp > v_hoy THEN
    est_final := 'proximo';
  ELSE
    est_final := CASE
      WHEN todas_pagadas   THEN 'completo'
      WHEN cuotas_vencidas > 0   THEN 'atrasado'
      WHEN cuota_hoy_pend   THEN 'pendiente'
      ELSE 'al_dia'
    END;
  END IF;

  -- actualiza cliente SIN tocar ultima_cuota (monto),
  -- solo saldo y número de última cuota pagada
  UPDATE public.clientes
    SET estado_pago          = est_final,
        dias_atraso          = cuotas_vencidas,
        saldo_pendiente      = (total_pagar - total_pagado),
        ultima_cuota_numero  = ultima_pag_num
   WHERE id = cid;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_pagos_aiud
  AFTER INSERT OR DELETE ON public.pagos
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_actualizar_estado();

-- ==========================================================
-- 8. (Opcional) Deshabilitar RLS mientras pruebas
-- ==========================================================
ALTER TABLE public.clientes    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cronograma DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos      DISABLE ROW LEVEL SECURITY;

-- ==========================================================
-- 9. FUNCIÓN: crear_historial_cerrado 
-- ==========================================================
CREATE OR REPLACE FUNCTION public.crear_historial_cerrado(p_cliente_id BIGINT)
  RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_cli               RECORD;
  v_total_pagado      NUMERIC;
  v_max_atraso        INTEGER;
  v_count_incidencias INTEGER;
  v_score             INTEGER;
BEGIN
  -- 1) Datos básicos del cliente
  SELECT * INTO v_cli
    FROM public.clientes
   WHERE id = p_cliente_id;

  -- 2) Suma de todos los pagos
  SELECT COALESCE(SUM(monto_pagado), 0)
    INTO v_total_pagado
    FROM public.pagos
   WHERE cliente_id = p_cliente_id;

  -- 3) Cálculo directo del atraso máximo
  SELECT
    COALESCE(
      MAX(
        (
          (p.fecha_pago AT TIME ZONE 'America/Lima')::date
          - cr.fecha_venc
        )
      ), 0
    )
  INTO v_max_atraso
  FROM public.pagos p
  JOIN public.cronograma cr
    ON p.cliente_id   = cr.cliente_id
   AND p.numero_cuota = cr.numero_cuota
  WHERE p.cliente_id = p_cliente_id;

  -- 4) Conteo de incidencias en historial_eventos
  SELECT COUNT(*) INTO v_count_incidencias
    FROM public.historial_eventos
   WHERE cliente_id = p_cliente_id
     AND tipo_evento = 'Incidencia';

  -- 5) Cálculo de la calificación
  v_score := GREATEST(
    0,
    LEAST(
      100,
      100 - v_max_atraso * 2 - v_count_incidencias * 5
    )
  );

  -- 6) Inserción en cliente_historial
  INSERT INTO public.cliente_historial(
    cliente_id, fecha_cierre, monto_solicitado, total_pagado,
    dias_totales, dias_atraso_max, incidencias,
    observaciones, calificacion
  ) VALUES (
    p_cliente_id,
    now(),
    v_cli.monto_solicitado,
    v_total_pagado,
    v_cli.plazo_dias,
    v_max_atraso,
    v_count_incidencias,
    NULL,
    v_score
  );
END;
$$;


-- ==========================================================
-- 10. TRIGGER: al insertar la última cuota en pagos
-- ==========================================================
CREATE OR REPLACE FUNCTION public._trigger_cierre_historial()
  RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_plazo INTEGER;
BEGIN
  SELECT plazo_dias INTO v_plazo
    FROM public.clientes
   WHERE id = NEW.cliente_id;

  IF TG_OP = 'INSERT' AND NEW.numero_cuota = v_plazo THEN
    PERFORM public.crear_historial_cerrado(NEW.cliente_id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pagos_cierre
  AFTER INSERT ON public.pagos
  FOR EACH ROW EXECUTE PROCEDURE public._trigger_cierre_historial();

-- ==========================================================
-- 11. AFTER INSERT: registrar cada pago en historial_eventos
-- ==========================================================
DROP TRIGGER IF EXISTS trg_log_pago ON public.pagos;

CREATE OR REPLACE FUNCTION public._trigger_log_pago()
  RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_fecha_venc DATE;
  v_atraso     INTEGER;
BEGIN
  -- Obtiene la fecha de vencimiento programada para esta cuota
  SELECT fecha_venc
    INTO v_fecha_venc
    FROM public.cronograma
   WHERE cliente_id   = NEW.cliente_id
     AND numero_cuota = NEW.numero_cuota;

  -- Calcula días de atraso (si la fecha real > programada)
  v_atraso := GREATEST(
    0,
    (NEW.fecha_pago AT TIME ZONE 'America/Lima')::date - v_fecha_venc
  );

  -- Inserta un evento detallado en historial_eventos
  INSERT INTO public.historial_eventos(
    cliente_id,
    tipo_evento,
    descripcion
  ) VALUES (
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

CREATE TRIGGER trg_log_pago
  AFTER INSERT ON public.pagos
  FOR EACH ROW
  EXECUTE PROCEDURE public._trigger_log_pago();

-- ==========================================================
-- 12. VISTA: exponer el historial completo de un cliente
-- ==========================================================
CREATE OR REPLACE VIEW public.v_cliente_historial_completo AS
WITH pagos_detalle AS (
  SELECT
    p.cliente_id,
    MIN(cr.fecha_venc)                                AS fecha_inicio,      -- primer vencimiento
    MAX(p.fecha_pago AT TIME ZONE 'America/Lima')     AS fecha_cierre_real, -- último pago real
    SUM(p.monto_pagado)                               AS total_pagado,
    MAX((p.fecha_pago AT TIME ZONE 'America/Lima')::date - cr.fecha_venc) 
      AS dias_atraso_max
  FROM public.pagos p
  JOIN public.cronograma cr
    ON p.cliente_id   = cr.cliente_id
   AND p.numero_cuota = cr.numero_cuota
  GROUP BY p.cliente_id
),
cliente_base AS (
  SELECT
    c.id                   AS cliente_id,
    c.monto_solicitado,
    c.plazo_dias           AS dias_totales
  FROM public.clientes c
)
SELECT
  cb.cliente_id,
  pd.fecha_inicio,
  pd.fecha_cierre_real,
  cb.monto_solicitado,
  pd.total_pagado,
  cb.dias_totales,
  GREATEST(pd.dias_atraso_max, 0) AS dias_atraso_max
FROM cliente_base cb
LEFT JOIN pagos_detalle pd ON pd.cliente_id = cb.cliente_id;

-- ==========================================================
-- 13. VISTA “AL VUELO” CORREGIDA: cuenta sólo cuotas vencidas y sin pagar
-- ==========================================================

DROP VIEW IF EXISTS public.v_clientes_con_estado;
CREATE VIEW public.v_clientes_con_estado AS
WITH mora AS (
  SELECT
    cr.cliente_id,
    -- Sólo las cuotas vencidas y sin pagar:
    COUNT(*) FILTER (
      WHERE cr.fecha_venc < (now() AT TIME ZONE 'America/Lima')::date
        AND cr.fecha_pagado IS NULL
    )                                  AS cuotas_vencidas,
    -- ¿Hay una cuota pendiente HOY?
    EXISTS (
      SELECT 1
      FROM public.cronograma c2
      WHERE c2.cliente_id   = cr.cliente_id
        AND c2.fecha_venc   = (now() AT TIME ZONE 'America/Lima')::date
        AND c2.fecha_pagado IS NULL
    )                                  AS cuota_hoy_pendiente,
    -- ¿Ya pagó todas?
    NOT EXISTS (
      SELECT 1
      FROM public.cronograma c3
      WHERE c3.cliente_id   = cr.cliente_id
        AND c3.fecha_pagado IS NULL
    )                                  AS todas_pagadas
  FROM public.cronograma cr
  GROUP BY cr.cliente_id
)
SELECT
  cli.id,
  cli.nombre,
  cli.telefono,
  cli.direccion,
  cli.negocio,
  cli.monto_solicitado,
  cli.plazo_dias,
  cli.fecha_creacion,
  cli.fecha_primer_pago,
  cli.fecha_final,
  cli.total_pagar,
  cli.cuota_diaria,
  cli.ultima_cuota,
  cli.saldo_pendiente,
  -- Renombrado para que el front use exactamente este nombre:
  m.cuotas_vencidas   AS dias_reales,
  CASE
    -- 1) Primer pago en el futuro → “próximo”
    WHEN (cli.fecha_primer_pago AT TIME ZONE 'America/Lima')::date
         > (now() AT TIME ZONE 'America/Lima')::date
      THEN 'proximo'
    -- 2) Todas las cuotas ya pagadas → “completo”
    WHEN m.todas_pagadas       THEN 'completo'
    -- 3) Vence hoy → “pendiente”
    WHEN m.cuota_hoy_pendiente THEN 'pendiente'
    -- 4) Ya hay cuotas vencidas → “atrasado”
    WHEN m.cuotas_vencidas > 0 THEN 'atrasado'
    -- 5) Si no aplica ninguno → “al_dia”
    ELSE 'al_dia'
  END                   AS estado_real
FROM public.clientes AS cli
LEFT JOIN mora m ON m.cliente_id = cli.id;
