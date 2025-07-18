const fs = require('fs');
const path = require('path');

// Lista de archivos a corregir con sus errores específicos
const fixes = [
  // 1. Archivos con catch (error) que usan error.message
  {
    file: 'lib/github/actions.ts',
    replacements: [
      {
        from: `    } catch (error) {
      console.error('[GitHubActions] Error verificando estado:', error)
      return {
        completed: false,
        success: false,
        error: error.message
      }
    }`,
        to: `    } catch (error) {
      console.error('[GitHubActions] Error verificando estado:', error)
      return {
        completed: false,
        success: false,
        error: error instanceof Error ? error.message : 'Error desconocido'
      }
    }`
      }
    ]
  },
  
  // 2. app/api/test-db/route.ts
  {
    file: 'app/api/test-db/route.ts',
    replacements: [
      {
        from: `      details: error.message,
      hint: error.hint,
      code: error.code`,
        to: `      details: error?.message || 'Error desconocido',
      hint: error?.hint || '',
      code: error?.code || ''`
      },
      {
        from: `    message: error.message`,
        to: `    message: error instanceof Error ? error.message : 'Error desconocido'`
      }
    ]
  },
  
  // 3. lib/apk/config-modifier.ts
  {
    file: 'lib/apk/config-modifier.ts',
    replacements: [
      {
        from: `      throw new Error(\`Error modificando APK: \${error.message}\`)`,
        to: `      throw new Error(\`Error modificando APK: \${error instanceof Error ? error.message : 'Error desconocido'}\`)`
      }
    ]
  },
  
  // 4. app/api/apk/generate/route.ts
  {
    file: 'app/api/apk/generate/route.ts',
    replacements: [
      {
        from: `        details: error.message,
        hint: error.hint,
        code: error.code`,
        to: `        details: error?.message || 'Error desconocido',
        hint: error?.hint || '',
        code: error?.code || ''`
      },
      {
        from: `            error_mensaje: localError.message`,
        to: `            error_mensaje: localError instanceof Error ? localError.message : 'Error desconocido'`
      },
      {
        from: `            error_mensaje: \`Local: \${localError.message}, GitHub: \${githubError.message}\``,
        to: `            error_mensaje: \`Local: \${localError instanceof Error ? localError.message : 'Error'}, GitHub: \${githubError instanceof Error ? githubError.message : 'Error'}\``
      },
      {
        from: `            local: localError.message,
            github: githubError.message`,
        to: `            local: localError instanceof Error ? localError.message : 'Error desconocido',
            github: githubError instanceof Error ? githubError.message : 'Error desconocido'`
      }
    ]
  },
  
  // 5. app/(auth)/login/create-test-user.tsx
  {
    file: 'app/(auth)/login/create-test-user.tsx',
    replacements: [
      {
        from: `      setMessage('Error: ' + error.message)`,
        to: `      setMessage('Error: ' + (error?.message || 'Error desconocido'))`
      }
    ]
  },
  
  // 6. app/(dashboard)/cobradores/page.tsx - Iniciales en nombres
  {
    file: 'app/(dashboard)/cobradores/page.tsx',
    replacements: [
      {
        from: `{cobrador.nombre.split(' ').map(n => n[0]).join('').slice(0, 2)}`,
        to: `{cobrador.nombre.split(' ').filter(n => n.length > 0).map(n => n[0]).join('').slice(0, 2)}`
      }
    ]
  },
  
  // 7. lib/github/actions.ts - workflow_runs[0]
  {
    file: 'lib/github/actions.ts',
    replacements: [
      {
        from: `      const run = runs.workflow_runs[0]`,
        to: `      const run = runs.workflow_runs?.[0]`
      }
    ]
  },
  
  // 8. app/api/apk/status/route.ts - workflowIdMatch[1]
  {
    file: 'app/api/apk/status/route.ts',
    replacements: [
      {
        from: `      const githubWorkflowId = workflowIdMatch[1]`,
        to: `      const githubWorkflowId = workflowIdMatch?.[1] || '0'`
      }
    ]
  }
];

// Función para aplicar las correcciones
function fixFile(filePath, replacements) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let modified = false;
    
    for (const replacement of replacements) {
      if (content.includes(replacement.from)) {
        content = content.replace(replacement.from, replacement.to);
        modified = true;
        console.log(`✅ Fixed: ${filePath}`);
      }
    }
    
    if (modified) {
      fs.writeFileSync(filePath, content, 'utf8');
    }
  } catch (error) {
    console.error(`❌ Error fixing ${filePath}:`, error.message);
  }
}

// Aplicar todas las correcciones
console.log('🔧 Arreglando errores de TypeScript...\n');

for (const fix of fixes) {
  const filePath = path.join(__dirname, fix.file);
  fixFile(filePath, fix.replacements);
}

console.log('\n✅ ¡Correcciones aplicadas! Ahora ejecuta npm run build para verificar.');