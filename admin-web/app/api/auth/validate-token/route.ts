import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { token } = body
    
    if (!token) {
      return NextResponse.json({ 
        valid: false, 
        message: 'Token requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // Verificar si el token existe y el cobrador está activo
    const { data: cobrador, error } = await supabase
      .from('cobradores')
      .select('id, nombre, dni, telefono, estado, token_acceso')
      .eq('token_acceso', token)
      .single()
    
    if (error || !cobrador) {
      console.log('[TokenValidation] Token no encontrado:', token.substring(0, 10) + '...')
      return NextResponse.json({ 
        valid: false, 
        message: 'Token inválido o cobrador no encontrado',
        reason: 'TOKEN_NOT_FOUND'
      })
    }
    
    // Verificar si el cobrador está activo
    if (cobrador.estado !== 'activo') {
      console.log(`[TokenValidation] Cobrador inactivo: ${cobrador.nombre} (${cobrador.estado})`)
      return NextResponse.json({ 
        valid: false, 
        message: 'Cobrador desactivado',
        reason: 'COBRADOR_DISABLED',
        cobrador: {
          nombre: cobrador.nombre,
          dni: cobrador.dni,
          estado: cobrador.estado
        }
      })
    }
    
    // Actualizar última conexión
    await supabase
      .from('cobradores')
      .update({ 
        ultima_conexion: new Date().toISOString()
      })
      .eq('id', cobrador.id)
    
    console.log(`[TokenValidation] ✅ Token válido para: ${cobrador.nombre}`)
    
    return NextResponse.json({ 
      valid: true, 
      message: 'Token válido',
      cobrador: {
        id: cobrador.id,
        nombre: cobrador.nombre,
        dni: cobrador.dni,
        telefono: cobrador.telefono,
        estado: cobrador.estado
      }
    })
    
  } catch (error) {
    console.error('[TokenValidation] Error validando token:', error)
    return NextResponse.json({ 
      valid: false, 
      message: 'Error interno del servidor',
      reason: 'SERVER_ERROR'
    }, { status: 500 })
  }
}

// GET method para verificaciones rápidas
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const token = searchParams.get('token')
    
    if (!token) {
      return NextResponse.json({ 
        valid: false, 
        message: 'Token requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // Verificación rápida solo de existencia y estado
    const { data: cobrador, error } = await supabase
      .from('cobradores')
      .select('id, nombre, estado')
      .eq('token_acceso', token)
      .eq('estado', 'activo')
      .single()
    
    if (error || !cobrador) {
      return NextResponse.json({ 
        valid: false,
        reason: !cobrador ? 'TOKEN_NOT_FOUND' : 'COBRADOR_DISABLED'
      })
    }
    
    return NextResponse.json({ 
      valid: true,
      cobrador: {
        id: cobrador.id,
        nombre: cobrador.nombre,
        estado: cobrador.estado
      }
    })
    
  } catch (error) {
    console.error('[TokenValidation] Error en verificación rápida:', error)
    return NextResponse.json({ 
      valid: false,
      reason: 'SERVER_ERROR'
    }, { status: 500 })
  }
}