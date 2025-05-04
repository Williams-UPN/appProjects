BEGIN;

-- 1) Deshabilitar triggers de validación (pero mantener el recálculo)
ALTER TABLE public.clientes DISABLE TRIGGER trg_clientes_bi;
ALTER TABLE public.clientes DISABLE TRIGGER trg_clientes_bu;

-- 2) Inserciones de prueba CON TODOS LOS CAMPOS calculados manualmente

-- ─────────────────────────────────────────────────────────────────────────────
-- Cliente Atrasado
-- plazo=24 → tasa=20% → total=2400*1.2=2880, cuota=ceil(2880/24)=120, última=2880-120*23=120
-- fecha_primer_pago=2025-04-17, fecha_final=2025-04-17+23d=2025-05-10
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Atrasado', '999111222', 'Calle Falsa 123', 'Negocio A',
  2400, 24, '2025-04-17 00:00:00-05',
  '2025-05-10 00:00:00-05', 2880, 120, 120
);
-- Pagos de las cuotas 1..14 a las 04:00 Lima
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 120, (date '2025-04-17' + (gs-1))::timestamptz AT TIME ZONE 'America/Lima' + time '04:00'
FROM public.clientes c
CROSS JOIN generate_series(1,14) AS gs
WHERE c.nombre = 'Cliente Atrasado';

-- ─────────────────────────────────────────────────────────────────────────────
-- Cliente Hoy Pendiente
-- plazo=12 → tasa=10% → total=1200*1.1=1320, cuota=ceil(1320/12)=110, última=1320-110*11=110
-- fecha_primer_pago=2025-04-23, fecha_final=2025-05-04
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy Pendiente', '999333444', 'Av. Siempre Viva', 'Negocio B',
  1200, 12, '2025-04-23 00:00:00-05',
  '2025-05-04 00:00:00-05', 1320, 110, 110
);
-- Pagos cuotas 1..9 a las 05:00 Lima
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 110, (date '2025-04-23' + (gs-1))::timestamptz AT TIME ZONE 'America/Lima' + time '05:00'
FROM public.clientes c
CROSS JOIN generate_series(1,9) AS gs
WHERE c.nombre = 'Cliente Hoy Pendiente';

-- ─────────────────────────────────────────────────────────────────────────────
-- Cliente Hoy-Mañana
-- plazo=12 → total=1000*1.1=1100, cuota=ceil(1100/12)=92, última=1100-92*11=88
-- fecha_primer_pago=2025-05-04, fecha_final=2025-05-15
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy-Mañana', '999555666', 'Calle Tres', 'Negocio C',
  1000, 12, '2025-05-04 00:00:00-05',
  '2025-05-15 00:00:00-05', 1100, 92, 88
);
-- Sin pagos aún (debe verse como “Próxima”)

-- ─────────────────────────────────────────────────────────────────────────────
-- Cliente Hoy-Hoy
-- mismo cálculo que Hoy-Mañana pero fecha_primer_pago=2025-05-03, fecha_final=2025-05-14
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy-Hoy', '999777888', 'Avenida Cuatro', 'Negocio D',
  1000, 12, '2025-05-03 00:00:00-05',
  '2025-05-14 00:00:00-05', 1100, 92, 88
);
-- Pago de la cuota 1 hoy a las 10:00 Lima
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT id, 1, 92, '2025-05-03 10:00:00-05'::timestamptz
FROM public.clientes
WHERE nombre = 'Cliente Hoy-Hoy';

-- ─────────────────────────────────────────────────────────────────────────────
-- Cliente Falta 11
-- primer pago=2025-04-22, fecha_final=2025-05-03, mismas cuotas que Hoy-Hoy
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Falta 11', '999999000', 'Paseo Central', 'Negocio E',
  1000, 12, '2025-04-22 00:00:00-05',
  '2025-05-03 00:00:00-05', 1100, 92, 88
);
-- Pagos cuotas 1..10 a las 09:00 Lima
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 92, (date '2025-04-22' + (gs-1))::timestamptz AT TIME ZONE 'America/Lima' + time '09:00'
FROM public.clientes c
CROSS JOIN generate_series(1,10) AS gs
WHERE c.nombre = 'Cliente Falta 11';

-- 3) Volver a habilitar triggers de validación/recálculo
ALTER TABLE public.clientes ENABLE TRIGGER trg_clientes_bi;
ALTER TABLE public.clientes ENABLE TRIGGER trg_clientes_bu;

COMMIT;
