import { exec } from 'child_process'
import { promisify } from 'util'
import path from 'path'
import fs from 'fs'
import AdmZip from 'adm-zip'

const execAsync = promisify(exec)

export class APKBuilder {
  private baseApkPath = path.join(process.cwd(), 'storage/base-apk/app-release.apk')
  private outputDir = path.join(process.cwd(), 'storage/generated')
  private toolsDir = path.join(process.cwd(), 'tools')
  private keystorePath = path.join(process.cwd(), 'storage/keystore/release.keystore')
  
  async buildAPK(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<string> {
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
      // 1. Copiar APK base a ubicación temporal
      const tempApkPath = path.join(outputPath, 'temp.apk')
      await fs.promises.copyFile(this.baseApkPath, tempApkPath)
      
      // 2. Importar y usar el modificador
      const { APKConfigModifier } = await import('./config-modifier')
      
      // 3. Verificar estructura del APK
      const hasValidStructure = await APKConfigModifier.verifyAPKStructure(tempApkPath)
      
      if (hasValidStructure) {
        // 4. Modificar APK con credenciales
        await APKConfigModifier.modifyAPK(tempApkPath, {
          cobrador_token: token,
          cobrador_nombre: nombre,
          cobrador_dni: credenciales.dni || 'N/A',
          supabase_url: credenciales.supabase_url,
          supabase_key: credenciales.supabase_key
        })
        
        console.log(`[APKBuilder] APK modificado con credenciales embebidas`)
      } else {
        console.warn(`[APKBuilder] APK no tiene estructura válida, usando sin modificar`)
      }
      
      // 5. Mover a ubicación final
      await fs.promises.rename(tempApkPath, outputApkPath)
      
      console.log(`[APKBuilder] APK generada exitosamente: ${outputApkPath}`)
      
      // Retornar ruta relativa para almacenar en BD
      return path.relative(process.cwd(), outputApkPath)
      
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
  }): Promise<string> {
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
    
    return path.relative(process.cwd(), signedApk)
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