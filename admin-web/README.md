# Panel Administrativo - Sistema de Cobros

Panel web administrativo para gestionar el sistema de préstamos y cobros.

## 🚀 Instalación Rápida

1. **Instalar dependencias**
```bash
npm install
```

2. **Configurar variables de entorno**
```bash
cp .env.local.example .env.local
```

Edita `.env.local` y agrega tus credenciales de Supabase:
```
NEXT_PUBLIC_SUPABASE_URL=https://dlpvictozfwiyjgxgwif.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_anon_key_aqui
```

3. **Ejecutar en modo desarrollo**
```bash
npm run dev
```

4. **Abrir en el navegador**
```
http://localhost:3000
```

## 📱 Características

- ✅ Dashboard con estadísticas en tiempo real
- ✅ Gestión completa de clientes
- ✅ Gestión de cobradores
- ✅ Registro y seguimiento de cobros
- ✅ Reportes y gráficos
- ✅ Diseño moderno y responsivo
- ✅ Animaciones fluidas
- ✅ Paleta de colores consistente con la app móvil

## 🎨 Diseño

El diseño sigue la misma paleta de colores que la app Flutter:
- Primario: `#BBDEFB` (Azul claro)
- Secundario: `#90CAF9` (Azul medio)
- Estados: Verde (completo), Naranja (pendiente), Rojo (atrasado)

## 🔐 Autenticación

Por ahora, cualquier usuario puede entrar con email/password válidos.
En el futuro se agregará verificación de roles (admin/cobrador).

## 📦 Tecnologías

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Supabase (Base de datos y auth)
- Framer Motion (Animaciones)
- Recharts (Gráficos)
- Lucide Icons

## 🚀 Despliegue

Para desplegar en Vercel:

1. Sube el código a GitHub
2. Importa el proyecto en Vercel
3. Configura las variables de entorno
4. ¡Listo!

## 📝 Notas

- El panel comparte la misma base de datos Supabase que la app móvil
- No necesitas crear un backend adicional
- Todas las operaciones se hacen directamente con Supabase