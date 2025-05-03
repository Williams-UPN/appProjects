-- Inserta al cliente con primer pago el 17-Abr-2025 (de modo que el día 17ª sea el 03-May-2025)
INSERT INTO clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias,
  fecha_primer_pago, fecha_final,
  total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Atrasado', '999111222', 'Calle Falsa 123', 'Negocio A',
  2400, 24,
  '2025-04-17'::timestamptz,  -- primer pago
  '2025-05-10'::timestamptz,  -- primer_pago + 23 días
  2400, 100, 0
);

-- El trigger generará automáticamente 24 filas en cronograma (17-Abr → 10-May).

-- Marcar las cuotas 1..14 como pagadas (fechas 17-Abr → 29-Abr)
INSERT INTO pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 100, (date '2025-04-17' + (gs-1))::timestamptz + time '10:00'
FROM clientes c
CROSS JOIN generate_series(1,14) gs
WHERE c.nombre = 'Cliente Atrasado';

-- Ahora:
--   cuotas_vencidas = count de 15 y 16 (fechas 2025-04-30 y 2025-05-01) → 2 días de atraso
--   cuota_hoy_pend = fecha 2025-05-03 (cuota 17) sin pagar
--   estado_pago = 'atrasado'
--   dias_atraso = 2
--   ultima_cuota = 14
--   saldo_pendiente = total_pagar - sum(pagos) = 2400 - 1400 = 1000


-- Inserta al cliente con primer pago el 23-Abr-2025 (de modo que la 11ª cuota caiga el 03-May)
INSERT INTO clientes (
  nombre, telefono, direccion, negocio,
  monto_solicitado, plazo_dias,
  fecha_primer_pago, fecha_final,
  total_pagar, cuota_diaria, ultima_cuota
) VALUES (
  'Cliente Hoy Pendiente', '999333444', 'Av. Siempre Viva', 'Negocio B',
  1200, 12,
  '2025-04-23'::timestamptz,
  '2025-05-04'::timestamptz,  -- primer_pago + 11 días
  1200, 100, 0
);

-- Se generarán 12 cuotas del 23-Abr al 04-May.

-- Marcar cuotas 1..9 como pagadas (23-Abr → 01-May)
INSERT INTO pagos (cliente_id, numero_cuota, monto_pagado, fecha_pago)
SELECT c.id, gs, 100, (date '2025-04-23' + (gs-1))::timestamptz + time '11:00'
FROM clientes c
CROSS JOIN generate_series(1,9) gs
WHERE c.nombre = 'Cliente Hoy Pendiente';

-- Ahora:
--   cuotas_vencidas = count de cuota 10 (fecha 2025-05-02) → 1 día de atraso
--   cuota_hoy_pend = cuota 11 (fecha 2025-05-03) sin pagar
--   estado_pago = 'atrasado'
--   dias_atraso = 1
--   ultima_cuota = 9
--   saldo_pendiente = 1200 - 900 = 300
