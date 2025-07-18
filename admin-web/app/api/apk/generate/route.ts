import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { APKBuilder } from '@/lib/apk/builder'
import { GitHubActionsBuilder } from '@/lib/github/actions'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { nombre, dni, telefono, email, foto } = body
    
    // Validar datos requeridos
    if (!nombre || !dni || !telefono) {
      return NextResponse.json({ 
        error: 'Faltan datos requeridos' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    // 1. Verificar si el DNI ya existe
    const { data: existingCobrador } = await supabase
      .from('cobradores')
      .select('id')
      .eq('dni', dni)
      .single()
    
    if (existingCobrador) {
      return NextResponse.json({ 
        error: 'Ya existe un cobrador con ese DNI' 
      }, { status: 400 })
    }
    
    // 2. Generar token único
    const token = generateSecureToken()
    
    // 3. Crear cobrador en base de datos
    const credenciales = {
      token,
      nombre,
      dni,
      supabase_url: process.env.NEXT_PUBLIC_SUPABASE_URL,
      supabase_key: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
      auto_login: true,
      version: '1.0.0'
    }
    
    const { data: cobrador, error } = await supabase
      .from('cobradores')
      .insert({
        nombre,
        dni,
        telefono,
        email,
        token_acceso: token,
        credenciales_embebidas: credenciales,
        estado: 'activo',
        zona_trabajo: 'Sin asignar'
      })
      .select()
      .single()
    
    if (error) {
      console.error('Error creando cobrador:', error)
      return NextResponse.json({ 
        error: 'Error al crear cobrador',
        details: error.message,
        hint: error.hint,
        code: error.code
      }, { status: 500 })
    }
    
    // 4. Crear build record
    const { data: build, error: buildError } = await supabase
      .from('apk_builds')
      .insert({
        cobrador_id: cobrador.id,
        estado: 'pending',
        metodo: 'local'
      })
      .select()
      .single()
    
    if (buildError) {
      console.error('Error creando build:', buildError)
      return NextResponse.json({ 
        error: 'Error al iniciar build' 
      }, { status: 500 })
    }
    
    // 5. Intentar build local primero
    console.log('Iniciando build local para:', nombre)
    
    try {
      // Actualizar estado a building
      await supabase
        .from('apk_builds')
        .update({ estado: 'building' })
        .eq('id', build.id)
      
      const builder = new APKBuilder()
      const startTime = Date.now()
      
      const apkResult = await builder.buildAPK({
        cobradorId: cobrador.id,
        nombre,
        token,
        credenciales
      })
      
      const buildTime = Date.now() - startTime
      
      // Actualizar build como completado
      await supabase
        .from('apk_builds')
        .update({
          estado: 'completed',
          apk_url: apkResult.path,
          fecha_fin: new Date().toISOString(),
          tiempo_build: buildTime
        })
        .eq('id', build.id)
      
      // Actualizar cobrador con URL de APK
      await supabase
        .from('cobradores')
        .update({
          apk_url: apkResult.path,
          apk_version: apkResult.version
        })
        .eq('id', cobrador.id)
      
      // Guardar métricas
      await supabase
        .from('build_metrics')
        .insert({
          metodo: 'local',
          tiempo_build: buildTime,
          fecha: new Date().toISOString(),
          exitoso: true
        })
      
      console.log('Build local completado exitosamente')
      
      return NextResponse.json({
        success: true,
        buildId: build.id,
        cobradorId: cobrador.id,
        apkUrl: apkResult.path,
        fileSize: apkResult.fileSize,
        version: apkResult.version,
        metodo: 'local',
        tiempo: buildTime
      })
      
    } catch (localError) {
      console.error('Build local falló:', localError)
      
      // Actualizar build como fallido
      await supabase
        .from('apk_builds')
        .update({
          estado: 'failed',
          error_mensaje: localError.message,
          fecha_fin: new Date().toISOString()
        })
        .eq('id', build.id)
      
      // Guardar métricas de fallo
      await supabase
        .from('build_metrics')
        .insert({
          metodo: 'local',
          tiempo_build: Date.now() - Date.now(),
          fecha: new Date().toISOString(),
          exitoso: false
        })
      
      // 6. Fallback a GitHub Actions
      console.log('Iniciando fallback a GitHub Actions')
      
      try {
        const githubBuilder = new GitHubActionsBuilder()
        
        const workflowRun = await githubBuilder.triggerBuild({
          cobradorId: cobrador.id,
          nombre,
          token,
          credenciales
        })
        
        // Actualizar build para GitHub Actions
        await supabase
          .from('apk_builds')
          .update({
            estado: 'building',
            metodo: 'github',
            log_build: `GitHub Actions workflow: ${workflowRun.id}`,
            error_mensaje: null
          })
          .eq('id', build.id)
        
        return NextResponse.json({
          success: true,
          buildId: build.id,
          cobradorId: cobrador.id,
          workflowId: workflowRun.id,
          metodo: 'github',
          message: 'Build local falló, usando GitHub Actions'
        })
        
      } catch (githubError) {
        console.error('GitHub Actions también falló:', githubError)
        
        await supabase
          .from('apk_builds')
          .update({
            estado: 'failed',
            error_mensaje: `Local: ${localError.message}, GitHub: ${githubError.message}`
          })
          .eq('id', build.id)
        
        return NextResponse.json({ 
          error: 'Ambos métodos de build fallaron',
          details: {
            local: localError.message,
            github: githubError.message
          }
        }, { status: 500 })
      }
    }
    
  } catch (error) {
    console.error('Error general en generación APK:', error)
    return NextResponse.json({ 
      error: 'Error interno del servidor' 
    }, { status: 500 })
  }
}

function generateSecureToken(): string {
  // Generar token seguro usando UUID + timestamp
  const uuid = crypto.randomUUID()
  const timestamp = Date.now().toString(36)
  return `${uuid}-${timestamp}`
}