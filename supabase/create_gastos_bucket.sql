-- ==============================================
-- SETUP COMPLETO PARA BUCKET DE GASTOS
-- ==============================================
-- Este script crea el bucket 'gastos-fotos' en Supabase Storage
-- con las políticas de seguridad necesarias

-- NOTA: Este SQL debe ejecutarse en el SQL Editor de Supabase Dashboard

-- 1. Crear el bucket (si no existe)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'gastos-fotos',
    'gastos-fotos', 
    true, -- Bucket público para URLs directas
    5242880, -- 5MB límite por archivo
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- 2. Política para permitir uploads autenticados
CREATE POLICY "Usuarios autenticados pueden subir fotos de gastos" 
ON storage.objects 
FOR INSERT 
TO authenticated 
WITH CHECK (
    bucket_id = 'gastos-fotos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 3. Política para permitir lectura pública
CREATE POLICY "Lectura pública de fotos de gastos" 
ON storage.objects 
FOR SELECT 
TO public 
USING (bucket_id = 'gastos-fotos');

-- 4. Política para permitir actualización por el propietario
CREATE POLICY "Usuarios pueden actualizar sus propias fotos" 
ON storage.objects 
FOR UPDATE 
TO authenticated 
USING (
    bucket_id = 'gastos-fotos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 5. Política para permitir eliminación por el propietario
CREATE POLICY "Usuarios pueden eliminar sus propias fotos" 
ON storage.objects 
FOR DELETE 
TO authenticated 
USING (
    bucket_id = 'gastos-fotos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- ==============================================
-- VERIFICAR QUE EL BUCKET SE CREÓ CORRECTAMENTE
-- ==============================================
SELECT * FROM storage.buckets WHERE id = 'gastos-fotos';

-- ==============================================
-- POLÍTICAS SIMPLIFICADAS (ALTERNATIVA)
-- ==============================================
-- Si las políticas anteriores dan problemas, usar estas más simples:

-- DROP POLICY IF EXISTS "Usuarios autenticados pueden subir fotos de gastos" ON storage.objects;
-- DROP POLICY IF EXISTS "Lectura pública de fotos de gastos" ON storage.objects;
-- DROP POLICY IF EXISTS "Usuarios pueden actualizar sus propias fotos" ON storage.objects;
-- DROP POLICY IF EXISTS "Usuarios pueden eliminar sus propias fotos" ON storage.objects;

-- CREATE POLICY "Acceso completo a usuarios autenticados" 
-- ON storage.objects 
-- FOR ALL 
-- TO authenticated 
-- USING (bucket_id = 'gastos-fotos')
-- WITH CHECK (bucket_id = 'gastos-fotos');

-- CREATE POLICY "Lectura pública" 
-- ON storage.objects 
-- FOR SELECT 
-- TO public 
-- USING (bucket_id = 'gastos-fotos');