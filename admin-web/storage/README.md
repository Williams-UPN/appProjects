# Storage Directory

Esta carpeta contiene los archivos necesarios para la generación de APKs:

## 📁 Estructura

```
storage/
├── base-apk/
│   └── app-release.apk          # APK base de Flutter (sin personalizar)
├── generated/
│   └── [cobrador-id]/
│       └── APK_[nombre]_v1.apk  # APKs generadas por cobrador
├── keystore/
│   └── release.keystore         # Keystore para firmar APKs
└── README.md
```

## 🔧 Configuración Inicial

### 1. APK Base
- Compila tu app Flutter: `flutter build apk --release`
- Copia `app-release.apk` a `storage/base-apk/`

### 2. Keystore
- Genera keystore: `keytool -genkey -v -keystore storage/keystore/release.keystore -alias releasekey -keyalg RSA -keysize 2048 -validity 10000`
- Configura las variables de entorno correspondientes

### 3. Permisos
- Asegúrate de que el directorio `storage/` tenga permisos de escritura
- Los archivos generados se crean automáticamente

## 🚫 Ignorar en Git

Agrega a `.gitignore`:
```
storage/base-apk/*.apk
storage/generated/
storage/keystore/*.keystore
```

## 📊 Limpieza Automática

Las APKs generadas se pueden limpiar automáticamente:
- Después de X días
- Cuando se genera una nueva versión
- Manualmente desde el panel admin