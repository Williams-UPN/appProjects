-- Crear tabla cobradores
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

-- Crear tabla apk_builds
CREATE TABLE apk_builds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cobrador_id UUID REFERENCES cobradores(id) ON DELETE CASCADE,
  estado VARCHAR DEFAULT 'pending',
  metodo VARCHAR, -- 'local' o 'github'
  log_build TEXT,
  fecha_inicio TIMESTAMP DEFAULT NOW(),
  fecha_fin TIMESTAMP,
  apk_url TEXT,
  error_mensaje TEXT,
  tamaño_apk BIGINT,
  tiempo_build INTEGER, -- en milisegundos
  
  CONSTRAINT apk_builds_estado_check CHECK (estado IN ('pending', 'building', 'completed', 'failed')),
  CONSTRAINT apk_builds_metodo_check CHECK (metodo IN ('local', 'github'))
);

-- Crear tabla build_logs (para debugging)
CREATE TABLE build_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  build_id UUID REFERENCES apk_builds(id) ON DELETE CASCADE,
  step VARCHAR NOT NULL,
  details JSONB,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Crear tabla build_metrics (para análisis)
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

-- Crear función para generar token único
CREATE OR REPLACE FUNCTION generate_unique_token()
RETURNS VARCHAR AS $$
BEGIN
  RETURN gen_random_uuid()::text || '-' || extract(epoch from now())::text;
END;
$$ LANGUAGE plpgsql;

-- Crear función para limpiar builds antiguos
CREATE OR REPLACE FUNCTION cleanup_old_builds()
RETURNS void AS $$
BEGIN
  DELETE FROM apk_builds 
  WHERE fecha_inicio < NOW() - INTERVAL '30 days'
  AND estado IN ('completed', 'failed');
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para auto-generar token
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

-- Insertar algunos cobradores de ejemplo
INSERT INTO cobradores (nombre, dni, telefono, email, credenciales_embebidas) VALUES
(
  'Juan Carlos Pérez',
  '12345678',
  '999888777',
  'juan.perez@email.com',
  '{
    "supabase_url": "https://your-project.supabase.co",
    "supabase_key": "your-anon-key"
  }'::jsonb
),
(
  'María López García',
  '87654321',
  '987654321',
  'maria.lopez@email.com',
  '{
    "supabase_url": "https://your-project.supabase.co",
    "supabase_key": "your-anon-key"
  }'::jsonb
),
(
  'Carlos Ruiz Mendoza',
  '11223344',
  '912345678',
  'carlos.ruiz@email.com',
  '{
    "supabase_url": "https://your-project.supabase.co",
    "supabase_key": "your-anon-key"
  }'::jsonb
);