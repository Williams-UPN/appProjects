import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createReadStream, existsSync, statSync } from 'fs'
import path from 'path'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const cobradorId = searchParams.get('cobradorId')
    const buildId = searchParams.get('buildId')
    
    if (!cobradorId && !buildId) {
      return NextResponse.json({ 
        error: 'cobradorId o buildId es requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    let apkPath: string | null = null
    let fileName: string = 'app.apk'
    
    if (cobradorId) {
      // Obtener APK más reciente del cobrador
      const { data: cobrador, error } = await supabase
        .from('cobradores')
        .select('apk_url, nombre, apk_version')
        .eq('id', cobradorId)
        .single()
      
      if (error || !cobrador) {
        return NextResponse.json({ 
          error: 'Cobrador no encontrado' 
        }, { status: 404 })
      }
      
      apkPath = cobrador.apk_url
      fileName = `APK_${cobrador.nombre.replace(/\s+/g, '')}_${cobrador.apk_version || 'v1'}.apk`
      
    } else if (buildId) {
      // Obtener APK por build ID
      const { data: build, error } = await supabase
        .from('apk_builds')
        .select(`
          apk_url,
          cobradores (
            nombre,
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
      
      apkPath = build.apk_url
      if (build.cobradores) {
        fileName = `APK_${build.cobradores.nombre.replace(/\s+/g, '')}_${build.cobradores.apk_version || 'v1'}.apk`
      }
    }
    
    if (!apkPath) {
      return NextResponse.json({ 
        error: 'APK no disponible' 
      }, { status: 404 })
    }
    
    // Verificar si el archivo existe
    const fullPath = path.isAbsolute(apkPath) ? apkPath : path.join(process.cwd(), apkPath)
    
    if (!existsSync(fullPath)) {
      return NextResponse.json({ 
        error: 'Archivo APK no encontrado en el servidor' 
      }, { status: 404 })
    }
    
    // Obtener información del archivo
    const stats = statSync(fullPath)
    const fileSize = stats.size
    
    // Crear stream del archivo
    const stream = createReadStream(fullPath)
    
    // Convertir el stream a un ReadableStream para la Response
    const readableStream = new ReadableStream({
      start(controller) {
        stream.on('data', (chunk) => {
          controller.enqueue(new Uint8Array(chunk))
        })
        
        stream.on('end', () => {
          controller.close()
        })
        
        stream.on('error', (error) => {
          controller.error(error)
        })
      }
    })
    
    // Configurar headers para descarga
    const headers = {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${fileName}"`,
      'Content-Length': fileSize.toString(),
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    }
    
    return new NextResponse(readableStream, {
      status: 200,
      headers
    })
    
  } catch (error) {
    console.error('Error descargando APK:', error)
    return NextResponse.json({ 
      error: 'Error interno del servidor' 
    }, { status: 500 })
  }
}

// Endpoint para obtener información del APK sin descargarlo
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { cobradorId, buildId } = body
    
    if (!cobradorId && !buildId) {
      return NextResponse.json({ 
        error: 'cobradorId o buildId es requerido' 
      }, { status: 400 })
    }
    
    const supabase = createClient()
    
    let query = supabase
      .from('apk_builds')
      .select(`
        *,
        cobradores (
          id,
          nombre,
          dni,
          apk_version,
          apk_url
        )
      `)
    
    if (cobradorId) {
      query = query.eq('cobrador_id', cobradorId)
    } else {
      query = query.eq('id', buildId)
    }
    
    const { data, error } = await query
      .eq('estado', 'completed')
      .order('fecha_fin', { ascending: false })
      .limit(1)
      .single()
    
    if (error || !data) {
      return NextResponse.json({ 
        error: 'APK no encontrada' 
      }, { status: 404 })
    }
    
    // Verificar si el archivo existe
    let fileExists = false
    let fileSize = 0
    
    if (data.apk_url) {
      const fullPath = path.isAbsolute(data.apk_url) ? data.apk_url : path.join(process.cwd(), data.apk_url)
      
      if (existsSync(fullPath)) {
        fileExists = true
        const stats = statSync(fullPath)
        fileSize = stats.size
      }
    }
    
    return NextResponse.json({
      buildId: data.id,
      cobradorId: data.cobrador_id,
      fileName: `APK_${data.cobradores?.nombre?.replace(/\s+/g, '')}_${data.cobradores?.apk_version || 'v1'}.apk`,
      fileSize,
      fileExists,
      apkUrl: data.apk_url,
      fechaCreacion: data.fecha_fin,
      metodo: data.metodo,
      tiempoBuild: data.tiempo_build,
      cobrador: data.cobradores ? {
        nombre: data.cobradores.nombre,
        dni: data.cobradores.dni,
        version: data.cobradores.apk_version
      } : null
    })
    
  } catch (error) {
    console.error('Error obteniendo información del APK:', error)
    return NextResponse.json({ 
      error: 'Error interno del servidor' 
    }, { status: 500 })
  }
}