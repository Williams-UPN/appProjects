# 📱 Instrucciones para Integrar tu App Flutter

## 🎯 Lo que TÚ debes hacer:

### 1️⃣ **En tu proyecto Flutter:**

#### a) Crear estructura de carpetas:
```bash
cd tu-proyecto-flutter
mkdir -p assets/config
```

#### b) Copiar archivos:
1. Copia `flutter-templates/assets/config/app_config.json` → `assets/config/app_config.json`
2. Copia `flutter-templates/lib/config_reader.dart` → `lib/config_reader.dart`

#### c) Modificar pubspec.yaml:
```yaml
flutter:
  # ... tu config actual ...
  assets:
    - assets/config/   # ← AGREGAR ESTA LÍNEA
```

#### d) Modificar tu main.dart:
```dart
// Al inicio agregar:
import 'config_reader.dart';

// En tu main() async agregar:
await ConfigReader.initialize();

// En tu lógica de navegación inicial:
if (ConfigReader.hasValidConfig() && ConfigReader.autoLogin) {
  // Ir directo a MainMenuScreen
} else {
  // Ir a login normal
}
```

### 2️⃣ **Compilar el APK:**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 3️⃣ **Copiar el APK:**
```bash
# El APK estará en: build/app/outputs/flutter-apk/app-release.apk
# Cópialo a: admin-web/storage/base-apk/app-release.apk
```

### 4️⃣ **Verificar que funciona:**
```bash
# En admin-web
npm run verify-apk
```

Si todo está bien, verás:
```
✅ Archivo de configuración encontrado!
🎉 ¡El APK está listo para ser modificado!
```

### 5️⃣ **Probar el sistema completo:**
1. Reinicia el servidor: `npm run dev`
2. Crea un nuevo cobrador
3. El sistema generará APK con credenciales embebidas

## 🔍 Archivos de referencia:

- `flutter-templates/lib/main_modificado.dart` - Ejemplo completo
- `flutter-templates/lib/config_reader.dart` - Clase helper
- `flutter-templates/assets/config/app_config.json` - Archivo de config

## ❓ Si tienes problemas:

1. Ejecuta `npm run verify-apk` para diagnosticar
2. Revisa que agregaste `assets/config/` en pubspec.yaml
3. Asegúrate de hacer `flutter clean` antes de compilar