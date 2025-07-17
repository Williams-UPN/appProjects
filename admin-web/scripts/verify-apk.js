const AdmZip = require('adm-zip');
const path = require('path');
const fs = require('fs');

console.log('🔍 Verificando APK base...\n');

const apkPath = path.join(__dirname, '../storage/base-apk/app-release.apk');

if (!fs.existsSync(apkPath)) {
  console.error('❌ No se encontró app-release.apk en storage/base-apk/');
  console.log('📝 Debes copiar tu APK de Flutter aquí primero.');
  process.exit(1);
}

try {
  const zip = new AdmZip(apkPath);
  const entries = zip.getEntries();
  
  console.log(`✅ APK encontrado: ${path.basename(apkPath)}`);
  console.log(`📦 Tamaño: ${(fs.statSync(apkPath).size / 1024 / 1024).toFixed(2)} MB`);
  console.log(`📋 Total de archivos: ${entries.length}\n`);
  
  // Buscar archivo de configuración
  const configPath = 'assets/flutter_assets/assets/config/app_config.json';
  const configEntry = entries.find(entry => entry.entryName === configPath);
  
  if (configEntry) {
    console.log('✅ Archivo de configuración encontrado!');
    console.log(`📍 Ubicación: ${configPath}`);
    
    // Leer contenido
    const configContent = zip.readAsText(configEntry);
    const config = JSON.parse(configContent);
    
    console.log('\n📄 Contenido actual:');
    console.log(JSON.stringify(config, null, 2));
    
    console.log('\n🎉 ¡El APK está listo para ser modificado!');
  } else {
    console.log('⚠️  No se encontró archivo de configuración');
    console.log(`❌ Buscando: ${configPath}`);
    console.log('\n📝 Asegúrate de:');
    console.log('   1. Crear assets/config/app_config.json en Flutter');
    console.log('   2. Agregar assets/config/ en pubspec.yaml');
    console.log('   3. Recompilar el APK');
    
    // Mostrar algunos archivos encontrados
    console.log('\n📁 Algunos archivos encontrados:');
    entries.slice(0, 10).forEach(entry => {
      if (entry.entryName.includes('assets')) {
        console.log(`   - ${entry.entryName}`);
      }
    });
  }
  
} catch (error) {
  console.error('❌ Error leyendo APK:', error.message);
}

console.log('\n-------------------');
console.log('Ejecuta: npm run verify-apk');