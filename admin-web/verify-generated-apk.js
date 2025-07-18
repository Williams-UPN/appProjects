const AdmZip = require('adm-zip');

async function verifyGeneratedAPK(apkPath) {
  try {
    console.log('🔍 Verificando APK generado:', apkPath);
    
    const zip = new AdmZip(apkPath);
    const configEntry = zip.getEntry('assets/flutter_assets/assets/config/app_config.json');
    
    if (!configEntry) {
      console.log('❌ No se encontró archivo de configuración');
      return;
    }
    
    const configData = zip.readAsText(configEntry);
    const config = JSON.parse(configData);
    
    console.log('📄 Configuración actual:');
    console.log(JSON.stringify(config, null, 2));
    
    // Verificar si las credenciales fueron reemplazadas
    if (config.cobrador_token === 'PLACEHOLDER_TOKEN') {
      console.log('❌ ERROR: Las credenciales NO fueron reemplazadas');
      console.log('🔧 El APK todavía contiene placeholders');
    } else {
      console.log('✅ SUCCESS: Las credenciales fueron reemplazadas correctamente');
    }
    
  } catch (error) {
    console.error('❌ Error verificando APK:', error.message);
  }
}

// Verificar el APK generado
verifyGeneratedAPK('storage/generated/f1409b5a-8870-4df4-8d19-6e42803b3d44/APK_nuevo_v1.apk');