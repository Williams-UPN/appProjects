-- Verificar si las tablas ya existen
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('cobradores', 'apk_builds', 'build_logs', 'build_metrics');

-- Si este query retorna resultados, las tablas ya existen
-- y deberías revisar antes de ejecutar el SQL de creación