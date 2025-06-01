-- ==============================================
-- OPCIÓN 1: Deshabilitar RLS en tabla gastos
-- ==============================================
-- SOLO PARA DESARROLLO - NO USAR EN PRODUCCIÓN

-- Deshabilitar RLS (cualquiera puede leer/escribir)
ALTER TABLE "public"."gastos" DISABLE ROW LEVEL SECURITY;

-- Hacer el campo usuario_id opcional
ALTER TABLE "public"."gastos" 
ALTER COLUMN "usuario_id" DROP NOT NULL,
ALTER COLUMN "usuario_id" SET DEFAULT 'anonimo';

-- Verificar que RLS está deshabilitado
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'gastos';