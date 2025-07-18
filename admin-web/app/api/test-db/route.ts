import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: NextRequest) {
  try {
    const supabase = createClient()
    
    // Intentar leer cobradores
    const { data, error } = await supabase
      .from('cobradores')
      .select('id, nombre, dni')
      .limit(5)
    
    if (error) {
      return NextResponse.json({ 
        error: 'Error leyendo base de datos',
        details: error?.message || 'Error desconocido',
        hint: error?.hint || '',
        code: error?.code || ''
      }, { status: 500 })
    }
    
    return NextResponse.json({ 
      success: true,
      count: data?.length || 0,
      data: data || []
    })
    
  } catch (error) {
    return NextResponse.json({ 
      error: 'Error general',
      message: error instanceof Error ? error.message : 'Error desconocido'
    }, { status: 500 })
  }
}