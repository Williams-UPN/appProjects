-- ==============================================
-- FIX: Políticas RLS para tabla gastos
-- ==============================================
-- Este script agrega las políticas faltantes para INSERT, UPDATE y DELETE

-- 1. Política para INSERT (crear gastos)
CREATE POLICY "Usuarios pueden crear sus propios gastos" 
ON "public"."gastos" 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid()::text = usuario_id);

-- 2. Política para UPDATE (actualizar gastos)
CREATE POLICY "Usuarios pueden actualizar sus propios gastos" 
ON "public"."gastos" 
FOR UPDATE 
TO authenticated 
USING (auth.uid()::text = usuario_id)
WITH CHECK (auth.uid()::text = usuario_id);

-- 3. Política para DELETE (eliminar gastos)
CREATE POLICY "Usuarios pueden eliminar sus propios gastos" 
ON "public"."gastos" 
FOR DELETE 
TO authenticated 
USING (auth.uid()::text = usuario_id);

-- Verificar que las políticas se crearon
SELECT schemaname, tablename, policyname, permissive, cmd
FROM pg_policies 
WHERE tablename = 'gastos'
ORDER BY cmd;