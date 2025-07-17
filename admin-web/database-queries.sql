-- QUERIES ÚTILES PARA EXPLORAR TU BASE DE DATOS SUPABASE

-- 1. Ver todas las tablas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 2. Ver estructura de una tabla específica
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'clientes'
ORDER BY ordinal_position;

-- 3. Ver todas las vistas
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public'
ORDER BY table_name;

-- 4. Contar registros en cada tabla
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- 5. Ver primeros 10 clientes
SELECT * FROM clientes LIMIT 10;

-- 6. Ver estructura de todas las tablas de un vistazo
SELECT 
    t.table_name,
    string_agg(
        c.column_name || ' (' || c.data_type || 
        CASE 
            WHEN c.character_maximum_length IS NOT NULL 
            THEN '(' || c.character_maximum_length || ')' 
            ELSE '' 
        END || ')', 
        ', ' ORDER BY c.ordinal_position
    ) as columns
FROM information_schema.tables t
JOIN information_schema.columns c ON c.table_name = t.table_name
WHERE t.table_schema = 'public' 
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;

-- 7. Ver si existe tabla usuarios
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'usuarios'
);

-- 8. Ver usuarios de Supabase Auth (si están usando Auth)
SELECT 
    id,
    email,
    created_at,
    last_sign_in_at
FROM auth.users
LIMIT 10;

-- 9. Script para crear tabla usuarios si no existe
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

-- 10. Ver relaciones entre tablas
SELECT
    tc.table_name as tabla_origen,
    kcu.column_name as columna_origen,
    ccu.table_name AS tabla_referencia,
    ccu.column_name AS columna_referencia
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;