-- =====================================================
-- SISTEMA DE GESTIÓN DE COBRADORES Y APK
-- =====================================================
-- Este SQL crea el sistema completo para:
-- 1. Gestionar cobradores (usuarios de la app móvil)
-- 2. Generar APKs personalizadas para cada cobrador
-- 3. Mantener historial de todas las generaciones
-- 4. Tracking de errores y métricas
-- =====================================================

-- Crear tabla principal de cobradores
CREATE TABLE cobradores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR NOT NULL,
  dni VARCHAR NOT NULL UNIQUE,
  telefono VARCHAR NOT NULL,
  email VARCHAR,
  foto_url TEXT,
  token_acceso VARCHAR NOT NULL UNIQUE,
  estado VARCHAR DEFAULT 'activo',
  apk_version VARCHAR,
  apk_url TEXT,
  fecha_creacion TIMESTAMP DEFAULT NOW(),
  ultima_conexion TIMESTAMP,
  zona_trabajo VARCHAR,
  credenciales_embebidas JSONB,
  
  CONSTRAINT cobradores_estado_check CHECK (estado IN ('activo', 'inactivo', 'suspendido'))
);

-- Crear tabla de historial de builds de APK
CREATE TABLE apk_builds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cobrador_id UUID REFERENCES cobradores(id) ON DELETE CASCADE,
  estado VARCHAR DEFAULT 'pending',
  metodo VARCHAR,
  log_build TEXT,
  fecha_inicio TIMESTAMP DEFAULT NOW(),
  fecha_fin TIMESTAMP,
  apk_url TEXT,
  error_mensaje TEXT,
  tamaño_apk BIGINT,
  tiempo_build INTEGER,
  
  CONSTRAINT apk_builds_estado_check CHECK (estado IN ('pending', 'building', 'completed', 'failed')),
  CONSTRAINT apk_builds_metodo_check CHECK (metodo IN ('local', 'github'))
);

-- Crear tabla de logs detallados de build
CREATE TABLE build_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  build_id UUID REFERENCES apk_builds(id) ON DELETE CASCADE,
  step VARCHAR NOT NULL,
  details JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Crear tabla de métricas para análisis
CREATE TABLE build_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metodo VARCHAR NOT NULL,
  tiempo_build INTEGER NOT NULL,
  tamaño_apk BIGINT,
  fecha TIMESTAMP DEFAULT NOW(),
  exitoso BOOLEAN DEFAULT true
);

-- Crear índices para optimizar consultas
CREATE INDEX idx_cobradores_dni ON cobradores(dni);
CREATE INDEX idx_cobradores_token ON cobradores(token_acceso);
CREATE INDEX idx_cobradores_estado ON cobradores(estado);
CREATE INDEX idx_apk_builds_cobrador ON apk_builds(cobrador_id);
CREATE INDEX idx_apk_builds_estado ON apk_builds(estado);
CREATE INDEX idx_build_logs_build ON build_logs(build_id);
CREATE INDEX idx_build_metrics_fecha ON build_metrics(fecha);

-- Función para generar token único automáticamente
CREATE OR REPLACE FUNCTION generate_unique_token()
RETURNS VARCHAR AS $$
BEGIN
  RETURN gen_random_uuid()::text || '-' || extract(epoch from now())::text;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar builds antiguos (más de 30 días)
CREATE OR REPLACE FUNCTION cleanup_old_builds()
RETURNS void AS $$
BEGIN
  DELETE FROM apk_builds 
  WHERE fecha_inicio < NOW() - INTERVAL '30 days'
  AND estado IN ('completed', 'failed');
END;
$$ LANGUAGE plpgsql;

-- Trigger para auto-generar token cuando se crea un cobrador
CREATE OR REPLACE FUNCTION auto_generate_token()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.token_acceso IS NULL THEN
    NEW.token_acceso := generate_unique_token();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_generate_token
  BEFORE INSERT ON cobradores
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_token();

-- =====================================================
-- VISTAS ÚTILES PARA EL SISTEMA
-- =====================================================

-- Vista para ver cobradores con su último build
CREATE OR REPLACE VIEW vista_cobradores_apk AS
SELECT 
  c.*,
  ultimo_build.estado as ultimo_build_estado,
  ultimo_build.fecha_fin as ultimo_build_fecha,
  ultimo_build.metodo as ultimo_build_metodo,
  (SELECT COUNT(*) FROM apk_builds WHERE cobrador_id = c.id) as total_builds
FROM cobradores c
LEFT JOIN LATERAL (
  SELECT * FROM apk_builds 
  WHERE cobrador_id = c.id 
  ORDER BY fecha_inicio DESC 
  LIMIT 1
) ultimo_build ON true;

-- Vista para métricas del dashboard
CREATE OR REPLACE VIEW vista_metricas_builds AS
SELECT 
  DATE(fecha) as dia,
  metodo,
  COUNT(*) as total_builds,
  COUNT(*) FILTER (WHERE exitoso = true) as builds_exitosos,
  COUNT(*) FILTER (WHERE exitoso = false) as builds_fallidos,
  AVG(tiempo_build) as tiempo_promedio,
  AVG(tamaño_apk) as tamaño_promedio
FROM build_metrics
GROUP BY DATE(fecha), metodo
ORDER BY dia DESC;

-- =====================================================
-- DATOS DE EJEMPLO (OPCIONAL - COMENTAR SI NO QUIERES)
-- =====================================================

-- Insertar cobradores de ejemplo
INSERT INTO cobradores (nombre, dni, telefono, email, zona_trabajo, credenciales_embebidas) VALUES
(
  'Juan Carlos Pérez',
  '12345678',
  '999888777',
  'juan.perez@email.com',
  'Norte',
  jsonb_build_object(
    'supabase_url', current_setting('app.settings.supabase_url', true),
    'supabase_key', current_setting('app.settings.supabase_anon_key', true)
  )
),
(
  'María López García',
  '87654321',
  '987654321',
  'maria.lopez@email.com',
  'Sur',
  jsonb_build_object(
    'supabase_url', current_setting('app.settings.supabase_url', true),
    'supabase_key', current_setting('app.settings.supabase_anon_key', true)
  )
),
(
  'Carlos Ruiz Mendoza',
  '11223344',
  '912345678',
  'carlos.ruiz@email.com',
  'Centro',
  jsonb_build_object(
    'supabase_url', current_setting('app.settings.supabase_url', true),
    'supabase_key', current_setting('app.settings.supabase_anon_key', true)
  )
);

-- =====================================================
-- FUNCIONES ÚTILES PARA LA APLICACIÓN
-- =====================================================

-- Función para obtener estadísticas de un cobrador
CREATE OR REPLACE FUNCTION get_cobrador_stats(p_cobrador_id UUID)
RETURNS TABLE (
  total_builds INTEGER,
  builds_exitosos INTEGER,
  builds_fallidos INTEGER,
  ultimo_build_fecha TIMESTAMP,
  tiempo_promedio_build INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER as total_builds,
    COUNT(*) FILTER (WHERE estado = 'completed')::INTEGER as builds_exitosos,
    COUNT(*) FILTER (WHERE estado = 'failed')::INTEGER as builds_fallidos,
    MAX(fecha_fin) as ultimo_build_fecha,
    AVG(tiempo_build)::INTEGER as tiempo_promedio_build
  FROM apk_builds
  WHERE cobrador_id = p_cobrador_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- POLÍTICAS DE SEGURIDAD (RLS)
-- =====================================================

-- Habilitar RLS en las tablas
ALTER TABLE cobradores ENABLE ROW LEVEL SECURITY;
ALTER TABLE apk_builds ENABLE ROW LEVEL SECURITY;
ALTER TABLE build_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE build_metrics ENABLE ROW LEVEL SECURITY;

-- Política para que los admins puedan ver todo
CREATE POLICY "Admins pueden ver todos los cobradores" ON cobradores
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Admins pueden ver todos los builds" ON apk_builds
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Admins pueden ver todos los logs" ON build_logs
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Admins pueden ver todas las métricas" ON build_metrics
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');

-- =====================================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- =====================================================

COMMENT ON TABLE cobradores IS 'Tabla principal de cobradores que usan la app móvil';
COMMENT ON TABLE apk_builds IS 'Historial de todas las generaciones de APK por cobrador';
COMMENT ON TABLE build_logs IS 'Logs detallados de cada paso del proceso de build';
COMMENT ON TABLE build_metrics IS 'Métricas agregadas para análisis y optimización';

COMMENT ON COLUMN cobradores.token_acceso IS 'Token único para autenticación automática en la app';
COMMENT ON COLUMN cobradores.credenciales_embebidas IS 'JSON con credenciales que se embeben en el APK';
COMMENT ON COLUMN apk_builds.metodo IS 'Método usado: local (servidor) o github (GitHub Actions)';
COMMENT ON COLUMN apk_builds.tiempo_build IS 'Tiempo en milisegundos que tardó la generación';

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================