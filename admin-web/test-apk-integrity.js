const AdmZip = require('adm-zip');
const fs = require('fs');

async function testAPKIntegrity() {
  console.log('🔍 Probando integridad de APKs...\n');
  
  const baseApkPath = 'storage/base-apk/app-release.apk';
  const generatedApkPath = 'storage/generated/4b792b79-7dcb-4ee7-a338-ab4f8f00497b/APK_nnuevo_v1.apk';
  
  console.log('📦 APK Base:');
  await testSingleAPK(baseApkPath);
  
  console.log('\n📦 APK Generado:');
  await testSingleAPK(generatedApkPath);
}

async function testSingleAPK(apkPath) {
  try {
    if (!fs.existsSync(apkPath)) {
      console.log(`❌ Archivo no existe: ${apkPath}`);
      return;
    }
    
    const stats = fs.statSync(apkPath);
    console.log(`📊 Tamaño: ${(stats.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Probar como ZIP
    const zip = new AdmZip(apkPath);
    const entries = zip.getEntries();
    
    console.log(`📁 Archivos en APK: ${entries.length}`);
    
    // Verificar archivos críticos
    const criticalFiles = [
      'AndroidManifest.xml',
      'classes.dex',
      'META-INF/MANIFEST.MF'
    ];
    
    const missingFiles = [];
    for (const file of criticalFiles) {
      const found = entries.some(entry => entry.entryName === file);
      if (!found) {
        missingFiles.push(file);
      }
    }
    
    if (missingFiles.length === 0) {
      console.log('✅ Estructura APK válida');
    } else {
      console.log(`⚠️ Archivos faltantes: ${missingFiles.join(', ')}`);
    }
    
    // Verificar archivo de configuración
    const configEntry = zip.getEntry('assets/flutter_assets/assets/config/app_config.json');
    if (configEntry) {
      console.log('📄 Archivo de configuración encontrado');
      const config = JSON.parse(zip.readAsText(configEntry));
      console.log(`🔑 Token: ${config.cobrador_token ? 'Presente' : 'PLACEHOLDER'}`);
    } else {
      console.log('📄 Sin archivo de configuración');
    }
    
    console.log('✅ APK puede ser leído correctamente');
    
  } catch (error) {
    console.log(`❌ Error leyendo APK: ${error.message}`);
  }
}

testAPKIntegrity();