import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: NextRequest) {
  try {
    const supabase = createClient()
    
    // Usar la vista que creamos en SQL
    const { data: cobradores, error } = await supabase
      .from('vista_cobradores_apk')
      .select('*')
      .order('fecha_creacion', { ascending: false })
    
    if (error) {
      console.error('Error obteniendo cobradores:', error)
      return NextResponse.json({ error: 'Error al obtener cobradores' }, { status: 500 })
    }
    
    // Formatear datos para el frontend
    const formattedCobradores = cobradores?.map(cobrador => ({
      id: cobrador.id,
      nombre: cobrador.nombre,
      telefono: cobrador.telefono,
      zona: cobrador.zona_trabajo || 'Sin asignar',
      estado: determinarEstado(cobrador),
      apkVersion: cobrador.apk_version,
      ultimaConexion: formatearFecha(cobrador.ultima_conexion),
      cobrosHoy: Math.floor(Math.random() * 5000), // TODO: Conectar con datos reales
      metaHoy: 5000,
      totalBuilds: cobrador.total_builds || 0,
      ultimoBuildEstado: cobrador.ultimo_build_estado,
      ultimoBuildFecha: cobrador.ultimo_build_fecha
    })) || []
    
    return NextResponse.json({ 
      success: true, 
      cobradores: formattedCobradores 
    })
    
  } catch (error) {
    console.error('Error en GET /api/cobradores:', error)
    return NextResponse.json({ error: 'Error interno' }, { status: 500 })
  }
}

// Determinar estado del cobrador basado en conexión y APK
function determinarEstado(cobrador: any): 'online' | 'offline' | 'sin_apk' {
  if (!cobrador.apk_version || !cobrador.apk_url) {
    return 'sin_apk'
  }
  
  if (cobrador.ultima_conexion) {
    const ultimaConexion = new Date(cobrador.ultima_conexion)
    const ahora = new Date()
    const horasDiferencia = (ahora.getTime() - ultimaConexion.getTime()) / (1000 * 60 * 60)
    
    if (horasDiferencia < 1) {
      return 'online'
    }
  }
  
  return 'offline'
}

// Formatear fecha relativa
function formatearFecha(fecha: string | null): string {
  if (!fecha) return 'Nunca'
  
  const date = new Date(fecha)
  const ahora = new Date()
  const diferencia = ahora.getTime() - date.getTime()
  
  const minutos = Math.floor(diferencia / 60000)
  const horas = Math.floor(diferencia / 3600000)
  const dias = Math.floor(diferencia / 86400000)
  
  if (minutos < 60) return `Hace ${minutos} min`
  if (horas < 24) return `Hace ${horas} horas`
  if (dias < 30) return `Hace ${dias} días`
  
  return date.toLocaleDateString()
}

// DELETE - Eliminar cobrador
export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const cobradorId = searchParams.get('id')
    
    if (!cobradorId) {
      return NextResponse.json({ error: 'ID requerido' }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // Gracias a ON DELETE CASCADE, esto elimina todo el historial
    const { error } = await supabase
      .from('cobradores')
      .delete()
      .eq('id', cobradorId)
    
    if (error) {
      console.error('Error eliminando cobrador:', error)
      return NextResponse.json({ error: 'Error al eliminar' }, { status: 500 })
    }
    
    return NextResponse.json({ success: true, message: 'Cobrador eliminado con todo su historial' })
    
  } catch (error) {
    console.error('Error en DELETE /api/cobradores:', error)
    return NextResponse.json({ error: 'Error interno' }, { status: 500 })
  }
}