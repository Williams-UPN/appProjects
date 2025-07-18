import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { GitHubActionsBuilder } from '@/lib/github/actions'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const buildId = searchParams.get('buildId')
    
    if (!buildId) {
      return NextResponse.json({ 
        error: 'buildId es requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // Obtener información del build
    const { data: build, error } = await supabase
      .from('apk_builds')
      .select(`
        *,
        cobradores (
          id,
          nombre,
          dni,
          telefono,
          email,
          apk_url,
          apk_version
        )
      `)
      .eq('id', buildId)
      .single()
    
    if (error || !build) {
      return NextResponse.json({ 
        error: 'Build no encontrado' 
      }, { status: 404 })
    }
    
    // Si es GitHub Actions y está pendiente, verificar estado
    if (build.metodo === 'github' && build.estado === 'building') {
      try {
        const githubBuilder = new GitHubActionsBuilder()
        
        // Extraer workflow ID del log
        const workflowIdMatch = build.log_build?.match(/GitHub Actions workflow: (\d+)/)
        if (workflowIdMatch && workflowIdMatch[1]) {
          const workflowId = workflowIdMatch[1]
          const status = await githubBuilder.checkStatus(workflowId)
          
          if (status.completed) {
            // Actualizar estado en base de datos
            const updateData: any = {
              estado: status.success ? 'completed' : 'failed',
              fecha_fin: new Date().toISOString(),
              error_mensaje: status.error || null
            }
            
            if (status.success && status.apkUrl) {
              updateData.apk_url = status.apkUrl
            }
            
            await supabase
              .from('apk_builds')
              .update(updateData)
              .eq('id', buildId)
            
            // Si fue exitoso, actualizar cobrador
            if (status.success) {
              await supabase
                .from('cobradores')
                .update({
                  apk_url: status.apkUrl,
                  apk_version: 'v1'
                })
                .eq('id', build.cobrador_id)
            }
            
            // Actualizar datos locales
            build.estado = status.success ? 'completed' : 'failed'
            build.apk_url = status.apkUrl
            build.error_mensaje = status.error
          }
        }
      } catch (githubError) {
        console.error('Error verificando estado GitHub:', githubError)
      }
    }
    
    // Calcular progreso basado en estado
    const progress = calculateProgress(build.estado, build.metodo)
    
    return NextResponse.json({
      buildId,
      cobradorId: build.cobrador_id,
      estado: build.estado,
      metodo: build.metodo,
      progress,
      apkUrl: build.apk_url,
      error: build.error_mensaje,
      fechaInicio: build.fecha_inicio,
      fechaFin: build.fecha_fin,
      tiempoBuild: build.tiempo_build,
      cobrador: build.cobradores ? {
        nombre: build.cobradores.nombre,
        dni: build.cobradores.dni,
        telefono: build.cobradores.telefono,
        email: build.cobradores.email
      } : null,
      logs: build.log_build
    })
    
  } catch (error) {
    console.error('Error obteniendo estado del build:', error)
    return NextResponse.json({ 
      error: 'Error interno del servidor' 
    }, { status: 500 })
  }
}

function calculateProgress(estado: string, metodo: string): number {
  const progressMap = {
    'pending': 0,
    'building': metodo === 'local' ? 50 : 30,
    'completed': 100,
    'failed': 0
  }
  
  return progressMap[estado] || 0
}

// Endpoint para obtener logs detallados
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { buildId } = body
    
    if (!buildId) {
      return NextResponse.json({ 
        error: 'buildId es requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // Obtener logs detallados
    const { data: logs, error } = await supabase
      .from('build_logs')
      .select('*')
      .eq('build_id', buildId)
      .order('timestamp', { ascending: true })
    
    if (error) {
      return NextResponse.json({ 
        error: 'Error obteniendo logs' 
      }, { status: 500 })
    }
    
    return NextResponse.json({
      buildId,
      logs: logs || []
    })
    
  } catch (error) {
    console.error('Error obteniendo logs:', error)
    return NextResponse.json({ 
      error: 'Error interno del servidor' 
    }, { status: 500 })
  }
}