# Documentación Completa - Generación de APK Personalizada

## 📋 Resumen del Sistema

Este sistema implementa una solución híbrida para generar APKs personalizadas con credenciales embebidas. Cada cobrador tendrá su propia APK con acceso directo sin necesidad de login.

### Componentes Principales
- **Web Admin Panel**: Interfaz para crear cobradores y gestionar APKs
- **Flutter App**: Aplicación móvil base que se personaliza
- **Supabase**: Base de datos para almacenar información de cobradores
- **Hybrid APK Builder**: Sistema de generación híbrida (local + GitHub Actions)

## 🎯 Arquitectura del Sistema

### 1. Flujo de Trabajo
```
1. Admin crea cobrador en web → 
2. Sistema genera token único → 
3. Modifica APK con credenciales → 
4. Firma y optimiza APK → 
5. Proporciona descarga
```

### 2. Estrategia Híbrida
- **Método Primario**: Generación local rápida (30-60 segundos)
- **Método Fallback**: GitHub Actions para mayor confiabilidad
- **Ventajas**: Velocidad + Confiabilidad + Escalabilidad

## 📁 Estructura del Proyecto

```
admin-web/
├── app/
│   ├── (dashboard)/
│   │   ├── cobradores/
│   │   │   ├── page.tsx                 # Lista de cobradores
│   │   │   └── nuevo/
│   │   │       └── page.tsx             # Formulario crear cobrador
│   │   └── api/
│   │       └── apk/
│   │           ├── generate/
│   │           │   └── route.ts         # API generación APK
│   │           ├── download/
│   │           │   └── route.ts         # API descarga APK
│   │           └── status/
│   │               └── route.ts         # API estado generación
├── lib/
│   ├── apk/
│   │   ├── builder.ts                   # Lógica construcción APK
│   │   ├── modifier.ts                  # Modificación APK
│   │   └── signer.ts                    # Firmado APK
│   ├── github/
│   │   └── actions.ts                   # Integración GitHub Actions
│   └── supabase/
│       └── client.ts                    # Cliente Supabase
├── tools/
│   ├── aapt2                           # Android Asset Packaging Tool
│   ├── apksigner                       # APK Signer
│   └── zipalign                        # ZIP Align Tool
└── storage/
    ├── base-apk/
    │   └── app-release.apk             # APK base sin personalizar
    ├── generated/
    │   └── [cobrador-id]/
    │       └── app-[nombre].apk        # APKs generadas
    └── keystore/
        └── release.keystore            # Keystore para firmar
```

## 🔧 Implementación Detallada

### 1. Base de Datos (Supabase)

#### Tabla: cobradores
```sql
CREATE TABLE cobradores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR NOT NULL,
  dni VARCHAR NOT NULL UNIQUE,
  telefono VARCHAR NOT NULL,
  email VARCHAR,
  foto_url TEXT,
  token_acceso VARCHAR NOT NULL UNIQUE,
  estado VARCHAR DEFAULT 'activo',
  apk_version VARCHAR,
  apk_url TEXT,
  fecha_creacion TIMESTAMP DEFAULT NOW(),
  ultima_conexion TIMESTAMP,
  zona_trabajo VARCHAR,
  credenciales_embebidas JSONB
);
```

#### Tabla: apk_builds
```sql
CREATE TABLE apk_builds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cobrador_id UUID REFERENCES cobradores(id),
  estado VARCHAR DEFAULT 'pending', -- pending, building, completed, failed
  metodo VARCHAR, -- local, github
  log_build TEXT,
  fecha_inicio TIMESTAMP DEFAULT NOW(),
  fecha_fin TIMESTAMP,
  apk_url TEXT,
  error_mensaje TEXT
);
```

### 2. API Routes

#### `/api/apk/generate/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { APKBuilder } from '@/lib/apk/builder'
import { GitHubActionsBuilder } from '@/lib/github/actions'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { cobradorId, nombre, dni, telefono, email } = body
    
    const supabase = createClient()
    
    // 1. Crear registro en base de datos
    const token = generateSecureToken()
    
    const { data: cobrador, error } = await supabase
      .from('cobradores')
      .insert({
        nombre,
        dni,
        telefono,
        email,
        token_acceso: token,
        credenciales_embebidas: {
          token,
          nombre,
          dni,
          supabase_url: process.env.SUPABASE_URL,
          supabase_key: process.env.SUPABASE_ANON_KEY
        }
      })
      .select()
      .single()
    
    if (error) throw error
    
    // 2. Crear build record
    const { data: build } = await supabase
      .from('apk_builds')
      .insert({
        cobrador_id: cobrador.id,
        estado: 'pending',
        metodo: 'local'
      })
      .select()
      .single()
    
    // 3. Intentar build local primero
    const builder = new APKBuilder()
    
    try {
      const apkPath = await builder.buildAPK({
        cobradorId: cobrador.id,
        nombre,
        token,
        credenciales: cobrador.credenciales_embebidas
      })
      
      // Update build status
      await supabase
        .from('apk_builds')
        .update({
          estado: 'completed',
          apk_url: apkPath,
          fecha_fin: new Date()
        })
        .eq('id', build.id)
      
      return NextResponse.json({
        success: true,
        buildId: build.id,
        apkUrl: apkPath,
        metodo: 'local'
      })
      
    } catch (localError) {
      console.error('Local build failed:', localError)
      
      // 4. Fallback a GitHub Actions
      const githubBuilder = new GitHubActionsBuilder()
      
      const workflowRun = await githubBuilder.triggerBuild({
        cobradorId: cobrador.id,
        nombre,
        token,
        credenciales: cobrador.credenciales_embebidas
      })
      
      await supabase
        .from('apk_builds')
        .update({
          metodo: 'github',
          log_build: `GitHub Actions workflow: ${workflowRun.id}`
        })
        .eq('id', build.id)
      
      return NextResponse.json({
        success: true,
        buildId: build.id,
        workflowId: workflowRun.id,
        metodo: 'github'
      })
    }
    
  } catch (error) {
    console.error('APK Generation error:', error)
    return NextResponse.json({ error: 'Build failed' }, { status: 500 })
  }
}

function generateSecureToken(): string {
  return crypto.randomUUID() + '-' + Date.now().toString(36)
}
```

#### `/api/apk/status/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { GitHubActionsBuilder } from '@/lib/github/actions'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const buildId = searchParams.get('buildId')
  
  const supabase = createClient()
  
  const { data: build } = await supabase
    .from('apk_builds')
    .select('*, cobradores(*)')
    .eq('id', buildId)
    .single()
  
  if (!build) {
    return NextResponse.json({ error: 'Build not found' }, { status: 404 })
  }
  
  // Si es GitHub Actions, verificar estado
  if (build.metodo === 'github' && build.estado === 'pending') {
    const githubBuilder = new GitHubActionsBuilder()
    const status = await githubBuilder.checkStatus(build.log_build)
    
    if (status.completed) {
      // Actualizar estado en base de datos
      await supabase
        .from('apk_builds')
        .update({
          estado: status.success ? 'completed' : 'failed',
          apk_url: status.apkUrl,
          fecha_fin: new Date(),
          error_mensaje: status.error
        })
        .eq('id', buildId)
    }
  }
  
  return NextResponse.json({
    buildId,
    estado: build.estado,
    metodo: build.metodo,
    apkUrl: build.apk_url,
    error: build.error_mensaje,
    progress: calculateProgress(build.estado, build.metodo)
  })
}
```

### 3. APK Builder Local

#### `/lib/apk/builder.ts`
```typescript
import { exec } from 'child_process'
import { promisify } from 'util'
import path from 'path'
import fs from 'fs'
import { APKModifier } from './modifier'
import { APKSigner } from './signer'

const execAsync = promisify(exec)

export class APKBuilder {
  private baseApkPath = path.join(process.cwd(), 'storage/base-apk/app-release.apk')
  private outputDir = path.join(process.cwd(), 'storage/generated')
  private toolsDir = path.join(process.cwd(), 'tools')
  
  async buildAPK(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<string> {
    const { cobradorId, nombre, token, credenciales } = config
    
    // 1. Crear directorio de salida
    const outputPath = path.join(this.outputDir, cobradorId)
    await fs.promises.mkdir(outputPath, { recursive: true })
    
    // 2. Copiar APK base
    const tempApkPath = path.join(outputPath, 'temp.apk')
    await fs.promises.copyFile(this.baseApkPath, tempApkPath)
    
    // 3. Modificar APK con credenciales
    const modifier = new APKModifier(this.toolsDir)
    await modifier.embedCredentials(tempApkPath, credenciales)
    
    // 4. Firmar APK
    const signer = new APKSigner(this.toolsDir)
    const signedApkPath = path.join(outputPath, `APK_${nombre.replace(/\s+/g, '')}_v1.apk`)
    await signer.signAPK(tempApkPath, signedApkPath)
    
    // 5. Optimizar APK
    await this.optimizeAPK(signedApkPath)
    
    // 6. Limpiar archivos temporales
    await fs.promises.unlink(tempApkPath)
    
    return signedApkPath
  }
  
  private async optimizeAPK(apkPath: string): Promise<void> {
    const zipalignPath = path.join(this.toolsDir, 'zipalign')
    const tempPath = apkPath + '.temp'
    
    await execAsync(`${zipalignPath} -f -p 4 ${apkPath} ${tempPath}`)
    await fs.promises.rename(tempPath, apkPath)
  }
}
```

#### `/lib/apk/modifier.ts`
```typescript
import { exec } from 'child_process'
import { promisify } from 'util'
import path from 'path'
import fs from 'fs'
import AdmZip from 'adm-zip'

const execAsync = promisify(exec)

export class APKModifier {
  constructor(private toolsDir: string) {}
  
  async embedCredentials(apkPath: string, credenciales: any): Promise<void> {
    // 1. Extraer APK
    const zip = new AdmZip(apkPath)
    const extractDir = apkPath + '_extracted'
    zip.extractAllTo(extractDir, true)
    
    // 2. Modificar archivo de configuración
    const configPath = path.join(extractDir, 'assets/config/app_config.json')
    const config = {
      cobrador_token: credenciales.token,
      cobrador_nombre: credenciales.nombre,
      cobrador_dni: credenciales.dni,
      supabase_url: credenciales.supabase_url,
      supabase_key: credenciales.supabase_key,
      auto_login: true,
      version: '1.0.0'
    }
    
    await fs.promises.mkdir(path.dirname(configPath), { recursive: true })
    await fs.promises.writeFile(configPath, JSON.stringify(config, null, 2))
    
    // 3. Modificar AndroidManifest.xml si es necesario
    await this.modifyManifest(extractDir, credenciales)
    
    // 4. Recrear APK
    const newZip = new AdmZip()
    this.addDirectoryToZip(newZip, extractDir, '')
    newZip.writeZip(apkPath)
    
    // 5. Limpiar directorio temporal
    await fs.promises.rm(extractDir, { recursive: true, force: true })
  }
  
  private async modifyManifest(extractDir: string, credenciales: any): Promise<void> {
    const manifestPath = path.join(extractDir, 'AndroidManifest.xml')
    
    // Decompile manifest
    const aaptPath = path.join(this.toolsDir, 'aapt2')
    await execAsync(`${aaptPath} dump xmltree ${manifestPath}`)
    
    // Modify as needed (add metadata, permissions, etc.)
    // This is a simplified example - actual implementation would be more complex
  }
  
  private addDirectoryToZip(zip: AdmZip, dirPath: string, relativePath: string): void {
    const files = fs.readdirSync(dirPath)
    
    for (const file of files) {
      const filePath = path.join(dirPath, file)
      const zipPath = path.join(relativePath, file)
      
      if (fs.statSync(filePath).isDirectory()) {
        this.addDirectoryToZip(zip, filePath, zipPath)
      } else {
        zip.addLocalFile(filePath, path.dirname(zipPath))
      }
    }
  }
}
```

#### `/lib/apk/signer.ts`
```typescript
import { exec } from 'child_process'
import { promisify } from 'util'
import path from 'path'

const execAsync = promisify(exec)

export class APKSigner {
  private keystorePath = path.join(process.cwd(), 'storage/keystore/release.keystore')
  private keystorePass = process.env.KEYSTORE_PASSWORD || 'changeit'
  private keyAlias = process.env.KEY_ALIAS || 'releasekey'
  
  constructor(private toolsDir: string) {}
  
  async signAPK(inputPath: string, outputPath: string): Promise<void> {
    const apksignerPath = path.join(this.toolsDir, 'apksigner')
    
    const command = [
      apksignerPath,
      'sign',
      '--ks', this.keystorePath,
      '--ks-pass', `pass:${this.keystorePass}`,
      '--key-pass', `pass:${this.keystorePass}`,
      '--ks-key-alias', this.keyAlias,
      '--out', outputPath,
      inputPath
    ].join(' ')
    
    await execAsync(command)
    
    // Verificar firma
    await this.verifySignature(outputPath)
  }
  
  private async verifySignature(apkPath: string): Promise<void> {
    const apksignerPath = path.join(this.toolsDir, 'apksigner')
    
    try {
      await execAsync(`${apksignerPath} verify ${apkPath}`)
      console.log('APK signature verified successfully')
    } catch (error) {
      throw new Error(`APK signature verification failed: ${error}`)
    }
  }
}
```

### 4. GitHub Actions Fallback

#### `/lib/github/actions.ts`
```typescript
import { Octokit } from '@octokit/rest'

export class GitHubActionsBuilder {
  private octokit = new Octokit({
    auth: process.env.GITHUB_TOKEN
  })
  
  private owner = process.env.GITHUB_OWNER || 'your-username'
  private repo = process.env.GITHUB_REPO || 'admin-web'
  
  async triggerBuild(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<{ id: number; url: string }> {
    
    const { data: workflow } = await this.octokit.rest.actions.createWorkflowDispatch({
      owner: this.owner,
      repo: this.repo,
      workflow_id: 'build-apk.yml',
      ref: 'main',
      inputs: {
        cobrador_id: config.cobradorId,
        nombre: config.nombre,
        token: config.token,
        credenciales: JSON.stringify(config.credenciales)
      }
    })
    
    // Get the workflow run
    const { data: runs } = await this.octokit.rest.actions.listWorkflowRuns({
      owner: this.owner,
      repo: this.repo,
      workflow_id: 'build-apk.yml',
      per_page: 1
    })
    
    return {
      id: runs.workflow_runs[0].id,
      url: runs.workflow_runs[0].html_url
    }
  }
  
  async checkStatus(workflowId: string): Promise<{
    completed: boolean
    success: boolean
    apkUrl?: string
    error?: string
  }> {
    const { data: run } = await this.octokit.rest.actions.getWorkflowRun({
      owner: this.owner,
      repo: this.repo,
      run_id: parseInt(workflowId)
    })
    
    if (run.status === 'completed') {
      if (run.conclusion === 'success') {
        // Get artifacts
        const { data: artifacts } = await this.octokit.rest.actions.listWorkflowRunArtifacts({
          owner: this.owner,
          repo: this.repo,
          run_id: parseInt(workflowId)
        })
        
        const apkArtifact = artifacts.artifacts.find(a => a.name.endsWith('.apk'))
        
        return {
          completed: true,
          success: true,
          apkUrl: apkArtifact?.archive_download_url
        }
      } else {
        return {
          completed: true,
          success: false,
          error: `Workflow failed: ${run.conclusion}`
        }
      }
    }
    
    return {
      completed: false,
      success: false
    }
  }
}
```

#### `.github/workflows/build-apk.yml`
```yaml
name: Build APK

on:
  workflow_dispatch:
    inputs:
      cobrador_id:
        description: 'Cobrador ID'
        required: true
      nombre:
        description: 'Nombre del cobrador'
        required: true
      token:
        description: 'Token de acceso'
        required: true
      credenciales:
        description: 'Credenciales JSON'
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Java
      uses: actions/setup-java@v3
      with:
        java-version: '11'
        distribution: 'temurin'
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
    
    - name: Get dependencies
      run: flutter pub get
    
    - name: Create config file
      run: |
        mkdir -p assets/config
        echo '${{ github.event.inputs.credenciales }}' > assets/config/app_config.json
    
    - name: Build APK
      run: flutter build apk --release
    
    - name: Sign APK
      run: |
        echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > release.keystore
        jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore release.keystore build/app/outputs/flutter-apk/app-release.apk key0
    
    - name: Rename APK
      run: |
        mv build/app/outputs/flutter-apk/app-release.apk "APK_${{ github.event.inputs.nombre }}_v1.apk"
    
    - name: Upload APK
      uses: actions/upload-artifact@v3
      with:
        name: APK_${{ github.event.inputs.nombre }}_v1.apk
        path: "APK_${{ github.event.inputs.nombre }}_v1.apk"
```

### 5. Frontend Integration

#### Actualizar `/app/(dashboard)/cobradores/nuevo/page.tsx`
```typescript
// En el handleSubmit function
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault()
  setStep('generating')
  
  try {
    // Llamar a la API de generación
    const response = await fetch('/api/apk/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        nombre: formData.nombre,
        dni: formData.dni,
        telefono: formData.telefono,
        email: formData.email,
      }),
    })
    
    const result = await response.json()
    
    if (result.success) {
      // Monitorear progreso
      monitorProgress(result.buildId)
    } else {
      throw new Error(result.error)
    }
  } catch (error) {
    console.error('Error generando APK:', error)
    // Manejar error
  }
}

const monitorProgress = async (buildId: string) => {
  const checkStatus = async () => {
    const response = await fetch(`/api/apk/status?buildId=${buildId}`)
    const status = await response.json()
    
    setProgress(status.progress)
    
    if (status.estado === 'completed') {
      setStep('completed')
      setApkUrl(status.apkUrl)
    } else if (status.estado === 'failed') {
      throw new Error(status.error)
    } else {
      setTimeout(checkStatus, 2000) // Check every 2 seconds
    }
  }
  
  checkStatus()
}
```

## 🔐 Configuración de Seguridad

### 1. Variables de Entorno
```bash
# .env.local
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# GitHub Actions
GITHUB_TOKEN=your_github_token
GITHUB_OWNER=your_username
GITHUB_REPO=admin-web

# APK Signing
KEYSTORE_PASSWORD=your_keystore_password
KEY_ALIAS=releasekey
```

### 2. Keystore Generation
```bash
# Generar keystore para firmar APKs
keytool -genkey -v -keystore release.keystore -alias releasekey -keyalg RSA -keysize 2048 -validity 10000

# Convertir a base64 para GitHub Secrets
base64 -i release.keystore | pbcopy
```

## 🚀 Instalación y Configuración

### 1. Instalar Dependencias
```bash
npm install adm-zip @octokit/rest
```

### 2. Configurar Android Tools
```bash
# Descargar Android SDK Build Tools
# Copiar a tools/ directory:
# - aapt2
# - apksigner
# - zipalign

chmod +x tools/aapt2
chmod +x tools/apksigner
chmod +x tools/zipalign
```

### 3. Configurar Flutter Base APK
```bash
# En tu proyecto Flutter
flutter build apk --release
# Copiar app-release.apk a storage/base-apk/
```

### 4. Configurar GitHub Actions
```bash
# En tu repo de GitHub, configurar secrets:
# - KEYSTORE_BASE64
# - KEYSTORE_PASSWORD
# - KEY_ALIAS
```

## 📊 Monitoreo y Logs

### 1. Logs de Build
```typescript
// En APKBuilder
private async logBuildStep(step: string, details: any) {
  console.log(`[APK Build] ${step}:`, details)
  
  // Opcional: Guardar en base de datos
  await supabase.from('build_logs').insert({
    build_id: this.buildId,
    step,
    details: JSON.stringify(details),
    timestamp: new Date()
  })
}
```

### 2. Métricas de Performance
```typescript
// Rastrear tiempos de build
const startTime = Date.now()
await this.buildAPK(config)
const buildTime = Date.now() - startTime

await supabase.from('build_metrics').insert({
  metodo: 'local',
  tiempo_build: buildTime,
  tamaño_apk: apkSize,
  fecha: new Date()
})
```

## 🔧 Mantenimiento y Actualizaciones

### 1. Actualizar APK Base
```bash
# Proceso para actualizar la APK base
1. Compilar nueva versión Flutter
2. Reemplazar storage/base-apk/app-release.apk
3. Actualizar versión en base de datos
4. Regenerar APKs existentes si es necesario
```

### 2. Rotación de Tokens
```typescript
// Función para rotar tokens de cobradores
async function rotateToken(cobradorId: string) {
  const newToken = generateSecureToken()
  
  await supabase
    .from('cobradores')
    .update({ token_acceso: newToken })
    .eq('id', cobradorId)
  
  // Regenerar APK con nuevo token
  await regenerateAPK(cobradorId)
}
```

## 🎯 Casos de Error y Recuperación

### 1. Build Local Fallido
```typescript
// Manejo automático de fallback
try {
  await localBuild()
} catch (error) {
  console.log('Local build failed, switching to GitHub Actions')
  await githubBuild()
}
```

### 2. GitHub Actions Fallido
```typescript
// Reintento con diferentes configuraciones
const retryConfig = {
  maxRetries: 3,
  delay: 5000,
  exponentialBackoff: true
}

await retryBuild(config, retryConfig)
```

## 📱 Integración con Flutter App

### 1. Modificar main.dart
```dart
// En la app Flutter
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Leer configuración embebida
  final config = await loadEmbeddedConfig();
  
  if (config['auto_login'] == true) {
    // Auto-login con token embebido
    await authenticateWithToken(config['cobrador_token']);
  }
  
  runApp(MyApp(config: config));
}

Future<Map<String, dynamic>> loadEmbeddedConfig() async {
  try {
    final String response = await rootBundle.loadString('assets/config/app_config.json');
    return json.decode(response);
  } catch (e) {
    // Fallback a configuración por defecto
    return {};
  }
}
```

### 2. Configurar Supabase Client
```dart
// En la app Flutter
class SupabaseConfig {
  static late SupabaseClient client;
  
  static initialize(Map<String, dynamic> config) {
    client = SupabaseClient(
      config['supabase_url'],
      config['supabase_key'],
    );
  }
}
```

## 🔄 Proceso de Actualización

### 1. Actualizar APK Existente
```typescript
async function updateAPK(cobradorId: string) {
  const cobrador = await getCobrador(cobradorId)
  
  // Generar nueva APK con credenciales actualizadas
  const newApk = await buildAPK({
    cobradorId,
    nombre: cobrador.nombre,
    token: cobrador.token_acceso,
    credenciales: cobrador.credenciales_embebidas
  })
  
  // Actualizar registro
  await supabase
    .from('cobradores')
    .update({
      apk_url: newApk,
      apk_version: 'v' + (parseInt(cobrador.apk_version.slice(1)) + 1)
    })
    .eq('id', cobradorId)
}
```

Este sistema proporciona una solución completa, escalable y confiable para la generación de APKs personalizadas con credenciales embebidas, utilizando una estrategia híbrida que combina velocidad local con confiabilidad en la nube.