'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { 
  ArrowLeft, 
  User, 
  Phone, 
  Mail, 
  Upload,
  Save,
  Loader2,
  Check,
  Download,
  Share2,
  Copy,
  Eye,
  EyeOff,
  RefreshCw,
  Shield,
  CreditCard
} from 'lucide-react'
import Link from 'next/link'

export default function NuevoCobradorPage() {
  const [step, setStep] = useState<'form' | 'generating' | 'completed'>('form')
  const [formData, setFormData] = useState({
    nombre: '',
    telefono: '',
    dni: '',
    email: ''
  })
  const [progress, setProgress] = useState(0)
  const [showToken, setShowToken] = useState(false)
  const [buildResult, setBuildResult] = useState<any>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setStep('generating')
    
    try {
      // Llamar a la API real de generación
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
        // Guardar resultado para descarga
        setBuildResult(result)
        // Monitorear progreso real
        await monitorProgress(result.buildId)
      } else {
        throw new Error(result.error || 'Error generando APK')
      }
    } catch (error) {
      console.error('Error:', error)
      alert('Error generando APK: ' + error.message)
      setStep('form')
      setProgress(0)
    }
  }
  
  const monitorProgress = async (buildId: string) => {
    let currentProgress = 0
    
    const checkStatus = async () => {
      try {
        const response = await fetch(`/api/apk/status?buildId=${buildId}`)
        const status = await response.json()
        
        // Actualizar progreso suavemente
        if (status.progress > currentProgress) {
          for (let i = currentProgress; i <= status.progress; i += 5) {
            setProgress(i)
            await new Promise(resolve => setTimeout(resolve, 50))
          }
          currentProgress = status.progress
        }
        
        if (status.estado === 'completed') {
          setProgress(100)
          setTimeout(() => setStep('completed'), 500)
        } else if (status.estado === 'failed') {
          throw new Error(status.error || 'Build falló')
        } else {
          // Seguir verificando
          setTimeout(checkStatus, 2000)
        }
      } catch (error) {
        console.error('Error monitoreando:', error)
        alert('Error: ' + error.message)
        setStep('form')
      }
    }
    
    checkStatus()
  }

  const downloadApk = async () => {
    if (!buildResult) {
      alert('No hay APK para descargar')
      return
    }

    try {
      // Usar buildId para descargar
      const response = await fetch(`/api/apk/download?buildId=${buildResult.buildId}`)
      
      if (!response.ok) {
        throw new Error('Error al descargar APK')
      }

      // Obtener el archivo como blob
      const blob = await response.blob()
      
      // Crear URL temporal y descargar
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `APK_${formData.nombre.replace(/\s+/g, '')}_v1.apk`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      window.URL.revokeObjectURL(url)
    } catch (error) {
      console.error('Error downloading APK:', error)
      alert('Error al descargar APK: ' + error.message)
    }
  }

  if (step === 'generating') {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="max-w-lg w-full"
        >
          <div className="bg-white rounded-3xl shadow-2xl p-8">
            <h2 className="text-2xl font-bold text-center mb-8">Generando APK Personalizada</h2>
            
            <div className="space-y-6">
              <div className="flex justify-center">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                  className="w-20 h-20 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center"
                >
                  <Loader2 className="w-10 h-10 text-white" />
                </motion.div>
              </div>
              
              <div className="space-y-2">
                <div className="flex justify-between text-sm text-gray-600">
                  <span>Progreso</span>
                  <span>{progress}%</span>
                </div>
                <div className="h-3 bg-gray-200 rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${progress}%` }}
                    className="h-full bg-gradient-to-r from-blue-500 to-blue-600"
                  />
                </div>
              </div>
              
              <div className="space-y-3">
                <TaskItem completed={progress >= 20} text="Cobrador creado en base de datos" />
                <TaskItem completed={progress >= 40} text="Token de seguridad generado" />
                <TaskItem completed={progress >= 60} text="Compilando APK personalizada" />
                <TaskItem completed={progress >= 80} text="Firmando aplicación" />
                <TaskItem completed={progress >= 100} text="Optimizando archivo" />
              </div>
              
              <p className="text-center text-sm text-gray-500">
                Tiempo estimado: 2 minutos
              </p>
            </div>
          </div>
        </motion.div>
      </div>
    )
  }

  if (step === 'completed') {
    return (
      <div className="min-h-screen p-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="max-w-4xl mx-auto"
        >
          <div className="bg-white rounded-3xl shadow-xl overflow-hidden">
            {/* Header */}
            <div className="bg-gradient-to-r from-green-500 to-green-600 p-8 text-white">
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 bg-white/20 backdrop-blur rounded-2xl flex items-center justify-center">
                  <Check className="w-8 h-8" />
                </div>
                <div>
                  <h1 className="text-3xl font-bold">APK Generada Exitosamente</h1>
                  <p className="text-green-100 mt-1">Lista para {formData.nombre || 'Cobrador'}</p>
                </div>
              </div>
            </div>

            <div className="p-8 space-y-8">
              {/* APK Card */}
              <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl p-6 border border-blue-200">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-4">
                    <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg">
                      <Phone className="w-8 h-8 text-white" />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-gray-900">APK_{formData.nombre.replace(/\s+/g, '')}_v1.apk</h3>
                      <div className="flex items-center gap-4 text-sm text-gray-600 mt-1">
                        <span>Tamaño: {buildResult?.fileSize || 'Calculando...'}</span>
                        <span>•</span>
                        <span>Versión: {buildResult?.version || '1.0.0'}</span>
                        <span>•</span>
                        <span>ID: {buildResult?.cobradorId || 'Generando...'}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex gap-3">
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    onClick={() => downloadApk()}
                    className="flex-1 bg-blue-600 text-white px-6 py-3 rounded-xl font-medium flex items-center justify-center gap-2 hover:bg-blue-700 transition-colors"
                  >
                    <Download className="w-5 h-5" />
                    Descargar APK
                  </motion.button>
                  
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="px-6 py-3 bg-white border border-gray-200 rounded-xl font-medium flex items-center gap-2 hover:bg-gray-50 transition-colors"
                  >
                    <Share2 className="w-5 h-5" />
                    Compartir
                  </motion.button>
                </div>
              </div>

              {/* Instructions */}
              <div className="bg-gray-50 rounded-2xl p-6">
                <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-blue-600" />
                  Instrucciones de Instalación
                </h3>
                <ol className="space-y-2 text-gray-600">
                  <li>1. En el teléfono, activar "Fuentes desconocidas" en Ajustes → Seguridad</li>
                  <li>2. Descargar e instalar el archivo APK</li>
                  <li>3. Abrir la app - estará lista para usar sin necesidad de login</li>
                </ol>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="mt-4 px-4 py-2 bg-white border border-gray-200 rounded-lg text-sm font-medium flex items-center gap-2 hover:bg-gray-50"
                >
                  <Copy className="w-4 h-4" />
                  Copiar instrucciones
                </motion.button>
              </div>

              {/* Security Info */}
              <div className="bg-amber-50 rounded-2xl p-6 border border-amber-200">
                <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-amber-600" />
                  Datos de Seguridad
                </h3>
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Token de acceso:</span>
                    <div className="flex items-center gap-2">
                      <code className="bg-white px-3 py-1 rounded-lg text-sm">
                        {showToken ? 'xyz789abc123def456' : '••••••••••••••••••'}
                      </code>
                      <button
                        onClick={() => setShowToken(!showToken)}
                        className="p-2 hover:bg-amber-100 rounded-lg transition-colors"
                      >
                        {showToken ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">Válido hasta:</span>
                    <span className="font-medium">Sin expiración</span>
                  </div>
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="w-full mt-4 px-4 py-2 bg-amber-600 text-white rounded-lg font-medium flex items-center justify-center gap-2 hover:bg-amber-700"
                  >
                    <RefreshCw className="w-4 h-4" />
                    Regenerar Token
                  </motion.button>
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-3">
                <Link href="/cobradores" className="flex-1">
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="w-full px-6 py-3 bg-gray-100 rounded-xl font-medium hover:bg-gray-200 transition-colors"
                  >
                    Finalizar
                  </motion.button>
                </Link>
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => {
                    setStep('form')
                    setProgress(0)
                    setFormData({
                      nombre: '',
                      telefono: '',
                      dni: '',
                      email: ''
                    })
                  }}
                  className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 transition-colors"
                >
                  Crear Otro Cobrador
                </motion.button>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/cobradores">
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </motion.button>
        </Link>
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Nuevo Cobrador</h1>
          <p className="text-gray-500 mt-1">Crear cuenta y generar APK personalizada</p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Información Personal - Todo en una tarjeta */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white rounded-2xl shadow-lg p-8"
        >
          <h2 className="text-xl font-semibold mb-8 flex items-center gap-2">
            <User className="w-5 h-5 text-blue-600" />
            Información Personal
          </h2>
          
          {/* Primera fila: Nombre, DNI */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            {/* Nombre */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Nombre Completo *
              </label>
              <input
                type="text"
                required
                value={formData.nombre}
                onChange={(e) => setFormData({...formData, nombre: e.target.value})}
                className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                placeholder="Juan Carlos Pérez García"
              />
            </div>

            {/* DNI */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                DNI/CI *
              </label>
              <input
                type="text"
                required
                value={formData.dni}
                onChange={(e) => setFormData({...formData, dni: e.target.value})}
                className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                placeholder="12345678"
              />
            </div>
          </div>

          {/* Segunda fila: Teléfono, Email */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Teléfono */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Phone className="inline w-4 h-4 mr-1" />
                Teléfono *
              </label>
              <input
                type="tel"
                required
                value={formData.telefono}
                onChange={(e) => setFormData({...formData, telefono: e.target.value})}
                className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                placeholder="999 888 777"
              />
            </div>

            {/* Email */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Mail className="inline w-4 h-4 mr-1" />
                Email (opcional)
              </label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({...formData, email: e.target.value})}
                className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                placeholder="juanperez@email.com"
              />
            </div>
          </div>
        </motion.div>

        {/* Actions */}
        <div className="flex gap-4">
          <Link href="/cobradores" className="flex-1">
            <motion.button
              type="button"
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="w-full px-6 py-3 bg-gray-100 rounded-xl font-medium hover:bg-gray-200 transition-colors"
            >
              Cancelar
            </motion.button>
          </Link>
          
          <motion.button
            type="submit"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="flex-1 px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl font-medium flex items-center justify-center gap-2 hover:from-blue-700 hover:to-blue-800 transition-all"
          >
            <Save className="w-5 h-5" />
            Guardar y Generar APK
          </motion.button>
        </div>
      </form>
    </div>
  )
}

function TaskItem({ completed, text }: { completed: boolean; text: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      className="flex items-center gap-3"
    >
      <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: completed ? 1 : 0 }}
        className="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center"
      >
        <Check className="w-4 h-4 text-white" />
      </motion.div>
      {!completed && (
        <div className="w-6 h-6 border-2 border-gray-300 rounded-full" />
      )}
      <span className={completed ? "text-gray-900" : "text-gray-400"}>
        {text}
      </span>
    </motion.div>
  )
}