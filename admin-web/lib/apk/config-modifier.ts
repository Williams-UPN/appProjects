import AdmZip from 'adm-zip'
import path from 'path'
import fs from 'fs'

export class APKConfigModifier {
  /**
   * Modifica el archivo de configuración dentro del APK
   */
  static async modifyAPK(
    apkPath: string,
    config: {
      cobrador_token: string
      cobrador_nombre: string
      cobrador_dni: string
      supabase_url: string
      supabase_key: string
    }
  ): Promise<void> {
    try {
      console.log('[APKConfigModifier] Iniciando modificación de APK')
      
      // 1. Leer APK como ZIP
      const zip = new AdmZip(apkPath)
      
      // 2. Buscar el archivo de configuración
      const configPath = 'assets/flutter_assets/assets/config/app_config.json'
      
      // 3. Crear nueva configuración
      const newConfig = {
        cobrador_token: config.cobrador_token,
        cobrador_nombre: config.cobrador_nombre,
        cobrador_dni: config.cobrador_dni,
        supabase_url: config.supabase_url,
        supabase_key: config.supabase_key,
        admin_url: process.env.NEXTAUTH_URL || 'http://localhost:3000',
        auto_login: true,
        version: '1.0.0',
        generated_at: new Date().toISOString()
      }
      
      // 4. Verificar si el archivo de configuración existe
      const configEntry = zip.getEntry(configPath)
      if (!configEntry) {
        console.warn('[APKConfigModifier] Archivo de configuración no encontrado, creando uno nuevo')
        // Crear el archivo si no existe
        zip.addFile(configPath, Buffer.from(JSON.stringify(newConfig, null, 2)))
      } else {
        // Actualizar archivo existente
        zip.updateFile(configPath, Buffer.from(JSON.stringify(newConfig, null, 2)))
      }
      
      // 5. Crear un nuevo APK con compresión mínima para preservar integridad
      const newZip = new AdmZip()
      const entries = zip.getEntries()
      
      // Copiar todas las entradas al nuevo ZIP con configuración actualizada
      for (const entry of entries) {
        if (entry.entryName === configPath) {
          // Usar la nueva configuración
          newZip.addFile(entry.entryName, Buffer.from(JSON.stringify(newConfig, null, 2)))
        } else {
          // Copiar el resto de archivos tal como están
          newZip.addFile(entry.entryName, entry.getData())
        }
      }
      
      // Si no había archivo de configuración, agregarlo
      if (!configEntry) {
        newZip.addFile(configPath, Buffer.from(JSON.stringify(newConfig, null, 2)))
      }
      
      // 6. Escribir el nuevo APK
      newZip.writeZip(apkPath)
      
      console.log('[APKConfigModifier] APK modificado exitosamente')
      
    } catch (error) {
      console.error('[APKConfigModifier] Error:', error)
      throw new Error(`Error modificando APK: ${error.message}`)
    }
  }
  
  /**
   * Verifica si el APK tiene la estructura esperada
   */
  static async verifyAPKStructure(apkPath: string): Promise<boolean> {
    try {
      const zip = new AdmZip(apkPath)
      const entries = zip.getEntries()
      
      // Buscar archivo de configuración
      const hasConfig = entries.some(entry => 
        entry.entryName === 'assets/flutter_assets/assets/config/app_config.json'
      )
      
      if (!hasConfig) {
        console.warn('[APKConfigModifier] APK no contiene archivo de configuración')
        console.warn('Asegúrate de que Flutter incluya assets/config/ en pubspec.yaml')
      }
      
      return hasConfig
      
    } catch (error) {
      console.error('[APKConfigModifier] Error verificando APK:', error)
      return false
    }
  }
  
  /**
   * Extrae y muestra la configuración actual del APK
   */
  static async extractConfig(apkPath: string): Promise<any> {
    try {
      const zip = new AdmZip(apkPath)
      const configEntry = zip.getEntry('assets/flutter_assets/assets/config/app_config.json')
      
      if (!configEntry) {
        return null
      }
      
      const configData = zip.readAsText(configEntry)
      return JSON.parse(configData)
      
    } catch (error) {
      console.error('[APKConfigModifier] Error extrayendo config:', error)
      return null
    }
  }
}