-- ==============================================
-- OPCIÓN 2: Permitir usuario anónimo en gastos
-- ==============================================
-- Permite guardar gastos sin autenticación

-- 1. Hacer usuario_id opcional con valor por defecto
ALTER TABLE "public"."gastos" 
ALTER COLUMN "usuario_id" SET DEFAULT 'usuario_anonimo';

-- 2. Crear política que permite INSERT sin autenticación
CREATE POLICY "Permitir gastos anónimos" 
ON "public"."gastos" 
FOR ALL 
USING (true)
WITH CHECK (true);

-- 3. Opcional: Si quieres mantener la política original para usuarios autenticados
-- DROP POLICY IF EXISTS "Usuarios ven sus propios gastos" ON "public"."gastos";