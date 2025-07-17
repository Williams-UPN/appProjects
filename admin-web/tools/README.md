# Android Build Tools

Esta carpeta debe contener las herramientas de Android SDK necesarias para la generación de APKs.

## 📱 Herramientas Necesarias

### 1. aapt2 (Android Asset Packaging Tool)
- **Función**: Compilar y empaquetar recursos Android
- **Descarga**: Android SDK Build Tools
- **Uso**: Modificar manifiestos y recursos

### 2. apksigner
- **Función**: Firmar APKs con certificados
- **Descarga**: Android SDK Build Tools
- **Uso**: Firmar APKs para distribución

### 3. zipalign
- **Función**: Optimizar APKs para rendimiento
- **Descarga**: Android SDK Build Tools
- **Uso**: Alinear archivos ZIP para mejor rendimiento

## 🔧 Instalación

### Opción 1: Android Studio
1. Instala Android Studio
2. Ve a SDK Manager → SDK Tools
3. Descarga "Android SDK Build-Tools"
4. Copia los archivos desde:
   ```
   ~/Android/Sdk/build-tools/[version]/
   ```

### Opción 2: Command Line Tools
1. Descarga Command Line Tools de Android
2. Ejecuta: `sdkmanager "build-tools;33.0.0"`
3. Copia los archivos necesarios

## 📋 Configuración

Después de copiar los archivos:

```bash
# Dar permisos de ejecución (Linux/Mac)
chmod +x tools/aapt2
chmod +x tools/apksigner
chmod +x tools/zipalign

# Windows - no requiere permisos adicionales
```

## 📁 Estructura Final

```
tools/
├── aapt2                # Linux/Mac
├── aapt2.exe           # Windows
├── apksigner           # Linux/Mac
├── apksigner.bat       # Windows
├── zipalign            # Linux/Mac
├── zipalign.exe        # Windows
└── README.md
```

## 🚫 Ignorar en Git

Agrega a `.gitignore`:
```
tools/aapt2*
tools/apksigner*
tools/zipalign*
!tools/README.md
```

## ⚠️ Notas Importantes

- Los archivos son específicos por plataforma
- Asegúrate de usar la versión correcta para tu sistema
- Los archivos pueden ser grandes (50-100MB total)
- Mantén las herramientas actualizadas