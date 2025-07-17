-- SCRIPT PARA CONFIGURAR USUARIOS EN TU BASE DE DATOS
-- Ejecuta esto en el SQL Editor de Supabase

-- 1. Crear tabla usuarios (si no existe)
CREATE TABLE IF NOT EXISTS public.usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    telefono TEXT,
    rol TEXT NOT NULL DEFAULT 'cobrador' CHECK (rol IN ('admin', 'cobrador')),
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Agregar campos de auditoría a las tablas existentes
-- (Solo si no existen ya)

-- Para tabla clientes
ALTER TABLE public.clientes 
ADD COLUMN IF NOT EXISTS creado_por UUID REFERENCES usuarios(id),
ADD COLUMN IF NOT EXISTS actualizado_por UUID REFERENCES usuarios(id),
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Para tabla pagos
ALTER TABLE public.pagos 
ADD COLUMN IF NOT EXISTS registrado_por UUID REFERENCES usuarios(id),
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL;

-- Para tabla gastos
ALTER TABLE public.gastos 
ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES usuarios(id);

-- Para tabla historial_eventos
ALTER TABLE public.historial_eventos 
ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES usuarios(id);

-- 3. Crear función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 4. Crear triggers para actualizar updated_at
CREATE TRIGGER update_usuarios_updated_at BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clientes_updated_at BEFORE UPDATE ON clientes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Crear vista para el dashboard con información de usuarios
CREATE OR REPLACE VIEW v_dashboard_stats AS
WITH stats AS (
  SELECT 
    COUNT(DISTINCT c.id) as total_clientes,
    COUNT(DISTINCT CASE WHEN v.estado_real = 'atrasado' THEN c.id END) as clientes_atrasados,
    COUNT(DISTINCT CASE WHEN v.estado_real IN ('al_dia', 'pendiente') THEN c.id END) as clientes_activos,
    COALESCE(SUM(p.monto_pagado) FILTER (WHERE DATE(p.fecha_pago) = CURRENT_DATE), 0) as cobros_hoy,
    COALESCE(SUM(p.monto_pagado) FILTER (WHERE DATE(p.fecha_pago) >= CURRENT_DATE - INTERVAL '30 days'), 0) as cobros_mes,
    ROUND(
      COUNT(DISTINCT CASE WHEN DATE(p.fecha_pago) = CURRENT_DATE THEN p.cliente_id END)::numeric / 
      NULLIF(COUNT(DISTINCT CASE WHEN v.estado_real IN ('al_dia', 'pendiente', 'atrasado') THEN c.id END), 0) * 100, 
      2
    ) as tasa_cobro
  FROM clientes c
  LEFT JOIN v_clientes_con_estado v ON v.id = c.id
  LEFT JOIN pagos p ON p.cliente_id = c.id
)
SELECT * FROM stats;

-- 6. Crear usuarios de ejemplo (OPCIONAL)
-- NOTA: Estos usuarios son solo para la tabla, necesitas crear los usuarios en Supabase Auth también

-- INSERT INTO usuarios (email, nombre, rol, telefono) VALUES
-- ('admin@sistema.com', 'Administrador Principal', 'admin', '999-999-999'),
-- ('pedro@sistema.com', 'Pedro García', 'cobrador', '555-0001'),
-- ('ana@sistema.com', 'Ana Martínez', 'cobrador', '555-0002'),
-- ('luis@sistema.com', 'Luis Mendoza', 'cobrador', '555-0003');

-- 7. Verificar que todo se creó correctamente
SELECT 
    'usuarios' as tabla,
    COUNT(*) as registros,
    'Tabla de usuarios del sistema' as descripcion
FROM usuarios
UNION ALL
SELECT 
    'clientes con creado_por' as tabla,
    COUNT(*) FILTER (WHERE creado_por IS NOT NULL) as registros,
    'Clientes con usuario asignado' as descripcion
FROM clientes
UNION ALL
SELECT 
    'pagos con registrado_por' as tabla,
    COUNT(*) FILTER (WHERE registrado_por IS NOT NULL) as registros,
    'Pagos con usuario registrador' as descripcion
FROM pagos;

-- 8. Habilitar Row Level Security (RLS) para mayor seguridad (OPCIONAL)
-- ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pagos ENABLE ROW LEVEL SECURITY;