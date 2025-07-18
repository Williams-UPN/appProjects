import { exec } from 'child_process'
import { promisify } from 'util'
import path from 'path'
import fs from 'fs'
import AdmZip from 'adm-zip'

const execAsync = promisify(exec)

export class APKBuilder {
  protected baseApkPath = path.join(process.cwd(), 'storage/base-apk/app-release.apk')
  protected outputDir = path.join(process.cwd(), 'storage/generated')
  protected toolsDir = path.join(process.cwd(), 'tools')
  protected keystorePath = path.join(process.cwd(), 'storage/keystore/release.keystore')
  
  async buildAPK(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<{ path: string; fileSize: string; version: string }> {
    const { cobradorId, nombre, token, credenciales } = config
    
    console.log(`[APKBuilder] Iniciando build para ${nombre}`)
    
    // 1. Verificar que exista APK base
    if (!fs.existsSync(this.baseApkPath)) {
      throw new Error('APK base no encontrada. Debes copiar app-release.apk a storage/base-apk/')
    }
    
    // 2. Crear directorio de salida
    const outputPath = path.join(this.outputDir, cobradorId)
    await fs.promises.mkdir(outputPath, { recursive: true })
    
    // 3. Por ahora, simplemente copiar y renombrar
    // (En producción aquí modificarías el APK con las credenciales)
    const nombreLimpio = nombre.replace(/\s+/g, '').replace(/[^a-zA-Z0-9]/g, '')
    const outputApkPath = path.join(outputPath, `APK_${nombreLimpio}_v1.apk`)
    
    console.log(`[APKBuilder] Generando APK personalizada...`)
    
    try {
      // 1. Simplemente copiar APK base preservando integridad
      console.log(`[APKBuilder] Copiando APK base para cobrador: ${nombre}`)
      await fs.promises.copyFile(this.baseApkPath, outputApkPath)
      
      console.log(`[APKBuilder] Credenciales almacenadas en base de datos:`)
      console.log(`- Token: ${token}`)
      console.log(`- Nombre: ${nombre}`)
      console.log(`- DNI: ${credenciales.dni}`)
      
      // Verificar que el archivo se copió correctamente y calcular tamaño
      const stats = await fs.promises.stat(outputApkPath)
      const fileSizeBytes = stats.size
      const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(1)
      
      console.log(`[APKBuilder] APK copiado exitosamente: ${fileSizeMB} MB`)
      console.log(`[APKBuilder] APK generada exitosamente: ${outputApkPath}`)
      
      // Retornar información completa del APK
      return {
        path: path.relative(process.cwd(), outputApkPath),
        fileSize: `${fileSizeMB} MB`,
        version: '1.0.0'
      }
      
    } catch (error) {
      console.error('[APKBuilder] Error generando APK:', error)
      throw error
    }
  }
  
  // Método simplificado para verificar herramientas
  async checkTools(): Promise<boolean> {
    // En producción verificarías aapt2, apksigner, zipalign
    // Por ahora solo verificamos keystore
    if (!fs.existsSync(this.keystorePath)) {
      console.warn('[APKBuilder] Keystore no encontrado. Genera uno con keytool')
      return false
    }
    return true
  }
  
  // Método para limpiar APKs antiguas
  async cleanup(daysOld: number = 30): Promise<number> {
    let deleted = 0
    const now = Date.now()
    const maxAge = daysOld * 24 * 60 * 60 * 1000
    
    const cobradorDirs = await fs.promises.readdir(this.outputDir)
    
    for (const dir of cobradorDirs) {
      const dirPath = path.join(this.outputDir, dir)
      const stat = await fs.promises.stat(dirPath)
      
      if (stat.isDirectory()) {
        const files = await fs.promises.readdir(dirPath)
        
        for (const file of files) {
          if (file.endsWith('.apk')) {
            const filePath = path.join(dirPath, file)
            const fileStat = await fs.promises.stat(filePath)
            
            if (now - fileStat.mtimeMs > maxAge) {
              await fs.promises.unlink(filePath)
              deleted++
            }
          }
        }
      }
    }
    
    return deleted
  }
}

// Versión completa para cuando tengas las herramientas Android
export class APKBuilderFull extends APKBuilder {
  async buildAPK(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<{ path: string; fileSize: string; version: string }> {
    const { cobradorId, nombre, token, credenciales } = config
    
    // 1. Crear directorio temporal
    const tempDir = path.join(this.outputDir, cobradorId, 'temp')
    await fs.promises.mkdir(tempDir, { recursive: true })
    
    // 2. Descomprimir APK
    const zip = new AdmZip(this.baseApkPath)
    zip.extractAllTo(tempDir, true)
    
    // 3. Crear archivo de configuración
    const configPath = path.join(tempDir, 'assets/config/app_config.json')
    await fs.promises.mkdir(path.dirname(configPath), { recursive: true })
    await fs.promises.writeFile(configPath, JSON.stringify({
      cobrador_token: token,
      cobrador_nombre: nombre,
      cobrador_dni: credenciales.dni,
      supabase_url: credenciales.supabase_url,
      supabase_key: credenciales.supabase_key,
      auto_login: true,
      version: '1.0.0'
    }, null, 2))
    
    // 4. Recomprimir APK
    const newZip = new AdmZip()
    this.addFolderToZip(newZip, tempDir)
    
    const unsignedApk = path.join(this.outputDir, cobradorId, 'unsigned.apk')
    newZip.writeZip(unsignedApk)
    
    // 5. Firmar APK
    const nombreLimpio = nombre.replace(/\s+/g, '').replace(/[^a-zA-Z0-9]/g, '')
    const signedApk = path.join(this.outputDir, cobradorId, `APK_${nombreLimpio}_v1.apk`)
    
    await this.signAPK(unsignedApk, signedApk)
    
    // 6. Limpiar archivos temporales
    await fs.promises.rm(tempDir, { recursive: true, force: true })
    await fs.promises.unlink(unsignedApk)
    
    // Calcular tamaño del archivo
    const stats = await fs.promises.stat(signedApk)
    const fileSizeBytes = stats.size
    const fileSizeMB = (fileSizeBytes / (1024 * 1024)).toFixed(1)
    
    return {
      path: path.relative(process.cwd(), signedApk),
      fileSize: `${fileSizeMB} MB`,
      version: '1.0.0'
    }
  }
  
  private async signAPK(inputPath: string, outputPath: string): Promise<void> {
    const apksignerPath = path.join(this.toolsDir, 'apksigner')
    
    if (!fs.existsSync(apksignerPath)) {
      throw new Error('apksigner no encontrado. Descarga Android SDK Build Tools')
    }
    
    const command = [
      apksignerPath,
      'sign',
      '--ks', this.keystorePath,
      '--ks-pass', `pass:${process.env.KEYSTORE_PASSWORD}`,
      '--key-pass', `pass:${process.env.KEYSTORE_PASSWORD}`,
      '--ks-key-alias', process.env.KEY_ALIAS || 'releasekey',
      '--out', outputPath,
      inputPath
    ].join(' ')
    
    await execAsync(command)
  }
  
  private addFolderToZip(zip: AdmZip, folderPath: string, basePath: string = ''): void {
    const files = fs.readdirSync(folderPath)
    
    for (const file of files) {
      const filePath = path.join(folderPath, file)
      const stat = fs.statSync(filePath)
      
      if (stat.isDirectory()) {
        this.addFolderToZip(zip, filePath, path.join(basePath, file))
      } else {
        zip.addLocalFile(filePath, basePath)
      }
    }
  }
}