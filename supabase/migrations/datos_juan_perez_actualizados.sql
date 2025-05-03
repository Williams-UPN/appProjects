BEGIN;

-- 1) Deshabilitar solo la validación de fecha (y mantener el recálculo activo)
ALTER TABLE public.clientes DISABLE TRIGGER trg_clientes_bi;
ALTER TABLE public.clientes DISABLE TRIGGER trg_clientes_bu;

-- 2) Inserciones de prueba CON TODOS LOS CAMPOS

-- Cliente Atrasado (17-Abr-2025, plazo 24 días)
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Atrasado', '999111222', 'Calle Falsa 123', 'Negocio A',
  2400, 24, '2025-04-17'::timestamptz,
  '2025-05-10'::timestamptz, 2880, 120, 120
);
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 120, (date '2025-04-17' + (gs-1))::timestamptz + time '10:00'
FROM public.clientes c
CROSS JOIN generate_series(1,14) AS gs
WHERE c.nombre = 'Cliente Atrasado';

-- Cliente Hoy Pendiente (23-Abr-2025, plazo 12 días)
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy Pendiente', '999333444', 'Av. Siempre Viva', 'Negocio B',
  1200, 12, '2025-04-23'::timestamptz,
  '2025-05-04'::timestamptz, 1320, 110, 110
);
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 110, (date '2025-04-23' + (gs-1))::timestamptz + time '11:00'
FROM public.clientes c
CROSS JOIN generate_series(1,9) AS gs
WHERE c.nombre = 'Cliente Hoy Pendiente';

-- Cliente Hoy-Mañana (04-May primer pago, 12 días)
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy-Mañana', '999555666', 'Calle Tres', 'Negocio C',
  1000, 12, '2025-05-04'::timestamptz,
  '2025-05-15'::timestamptz, 1100, 92, 92
);

-- Cliente Hoy-Hoy (03-May registro y primer pago, 12 días)
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy-Hoy', '999777888', 'Avenida Cuatro', 'Negocio D',
  1000, 12, '2025-05-03'::timestamptz,
  '2025-05-14'::timestamptz, 1100, 92, 92
);
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT id, 1, 92, '2025-05-03 10:00'::timestamptz
FROM public.clientes
WHERE nombre = 'Cliente Hoy-Hoy';

-- **Cuarto cliente**: plazo 12 días, primer pago 22-Abr-2025, última cuota 03-May-2025
-- Pagos únicamente de las cuotas 1..10; las cuotas 11 y 12 quedan sin pagar.
INSERT INTO public.clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias, fecha_primer_pago,
  fecha_final, total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Falta 11', '999999000', 'Paseo Central', 'Negocio E',
  1000, 12, '2025-04-22'::timestamptz,
  '2025-05-03'::timestamptz, 1100, 92,  88
);

-- Pagos cuotas 1..10 (22-Abr → 01-May)
INSERT INTO public.pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 92, (date '2025-04-22' + (gs-1))::timestamptz + time '09:00'
FROM public.clientes c
CROSS JOIN generate_series(1,10) AS gs
WHERE c.nombre = 'Cliente Falta 11';


-- 3) Volver a habilitar triggers de validación/recálculo
ALTER TABLE public.clientes ENABLE TRIGGER trg_clientes_bi;
ALTER TABLE public.clientes ENABLE TRIGGER trg_clientes_bu;

COMMIT;
