'use client'

import { useState, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { motion } from 'framer-motion'
import Link from 'next/link'
import { 
  Plus, 
  Search, 
  Filter,
  Eye,
  Download,
  RefreshCw,
  Trash2,
  MoreVertical,
  MapPin,
  Phone,
  Signal,
  SignalZero,
  Clock,
  CheckCircle,
  Check,
  X
} from 'lucide-react'

interface Cobrador {
  id: string
  nombre: string
  dni: string
  telefono: string
  email: string
  zona_trabajo: string
  estado: 'activo' | 'inactivo' | 'suspendido'
  apk_version: string | null
  fecha_creacion: string
  ultima_conexion: string | null
  ultimo_build_estado: string | null
  ultimo_build_fecha: string | null
  ultimo_build_metodo: string | null
  total_builds: number
  token_acceso: string
}

interface DeleteModalData {
  id: string
  nombre: string
}

interface SuccessModalData {
  show: boolean
  message: string
  nombre?: string
}

export default function CobradoresPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [filterZona, setFilterZona] = useState('todos')
  const [filterEstado, setFilterEstado] = useState('todos')
  const [cobradores, setCobradores] = useState<Cobrador[]>([])
  const [loading, setLoading] = useState(true)
  const [showDeleteMenu, setShowDeleteMenu] = useState<string | null>(null)
  const [deleteModal, setDeleteModal] = useState<DeleteModalData | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [mounted, setMounted] = useState(false)
  const [successModal, setSuccessModal] = useState<SuccessModalData>({ show: false, message: '' })

  useEffect(() => {
    setMounted(true)
    fetchCobradores()
  }, [])

  // Cerrar menú al hacer clic afuera
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Element
      if (!target.closest('.menu-container')) {
        setShowDeleteMenu(null)
      }
    }
    document.addEventListener('click', handleClickOutside)
    return () => document.removeEventListener('click', handleClickOutside)
  }, [])

  const fetchCobradores = async () => {
    try {
      const response = await fetch('/api/cobradores')
      const data = await response.json()
      if (data.success) {
        setCobradores(data.cobradores || [])
      } else {
        console.error('Error en respuesta:', data.error)
        setCobradores([])
      }
    } catch (error) {
      console.error('Error cargando cobradores:', error)
      setCobradores([])
    } finally {
      setLoading(false)
    }
  }

  // Determinar estado para visualización
  const getEstadoVisual = (cobrador: Cobrador) => {
    if (!cobrador.apk_version || !cobrador.ultimo_build_estado) {
      return 'sin_apk'
    }
    
    if (cobrador.ultimo_build_estado !== 'completed') {
      return 'sin_apk'
    }
    
    if (cobrador.ultima_conexion) {
      const ultimaConexion = new Date(cobrador.ultima_conexion)
      const ahora = new Date()
      const horasDiferencia = (ahora.getTime() - ultimaConexion.getTime()) / (1000 * 60 * 60)
      
      if (horasDiferencia < 1) return 'online'
    }
    
    return 'offline'
  }

  // Formatear fecha relativa
  const formatearFecha = (fecha: string | null): string => {
    if (!fecha) return 'Nunca'
    
    const date = new Date(fecha)
    const ahora = new Date()
    const diferencia = ahora.getTime() - date.getTime()
    
    const minutos = Math.floor(diferencia / 60000)
    const horas = Math.floor(diferencia / 3600000)
    const dias = Math.floor(diferencia / 86400000)
    
    if (minutos < 60) return `Hace ${minutos} min`
    if (horas < 24) return `Hace ${horas} horas`
    if (dias < 30) return `Hace ${dias} días`
    
    return date.toLocaleDateString()
  }

  const getEstadoBadge = (estado: string) => {
    switch (estado) {
      case 'online':
        return (
          <span className="flex items-center gap-1.5 px-3 py-1.5 bg-green-100 text-green-700 rounded-full text-sm font-medium">
            <Signal className="w-4 h-4" />
            En línea
          </span>
        )
      case 'offline':
        return (
          <span className="flex items-center gap-1.5 px-3 py-1.5 bg-gray-100 text-gray-700 rounded-full text-sm font-medium">
            <SignalZero className="w-4 h-4" />
            Desconectado
          </span>
        )
      case 'sin_apk':
        return (
          <span className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-100 text-amber-700 rounded-full text-sm font-medium">
            <Clock className="w-4 h-4" />
            Sin APK
          </span>
        )
    }
  }

  // Filtrar cobradores
  const cobradoresFiltrados = cobradores.filter(cobrador => {
    const cumpleBusqueda = searchTerm === '' || 
      cobrador.nombre.toLowerCase().includes(searchTerm.toLowerCase()) ||
      cobrador.telefono.includes(searchTerm) ||
      cobrador.dni.includes(searchTerm)
    
    const cumpleZona = filterZona === 'todos' || 
      (cobrador.zona_trabajo && cobrador.zona_trabajo.toLowerCase().includes(filterZona.toLowerCase()))
    
    const estadoVisual = getEstadoVisual(cobrador)
    const cumpleEstado = filterEstado === 'todos' || estadoVisual === filterEstado
    
    return cumpleBusqueda && cumpleZona && cumpleEstado
  })

  // Descargar APK
  const downloadApk = async (cobradorId: string, nombre: string) => {
    try {
      const response = await fetch(`/api/apk/download?cobradorId=${cobradorId}`)
      
      if (!response.ok) {
        throw new Error('Error al descargar APK')
      }

      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `APK_${nombre.replace(/\s+/g, '')}_v1.apk`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
      window.URL.revokeObjectURL(url)
    } catch (error) {
      console.error('Error downloading APK:', error)
      alert('Error al descargar APK: ' + error.message)
    }
  }

  // Abrir modal de confirmación
  const openDeleteModal = (cobradorId: string, nombre: string) => {
    setDeleteModal({ id: cobradorId, nombre })
    setShowDeleteMenu(null) // Cerrar menú de opciones
  }

  // Eliminar cobrador
  const deleteCobrador = async () => {
    if (!deleteModal) return
    
    setDeleting(true)
    
    try {
      const response = await fetch(`/api/cobradores?id=${deleteModal.id}`, {
        method: 'DELETE'
      })
      
      const result = await response.json()
      
      if (result.success) {
        // Actualizar la lista eliminando el cobrador
        setCobradores(prev => prev.filter(c => c.id !== deleteModal.id))
        const nombreEliminado = deleteModal.nombre
        setDeleteModal(null)
        
        // Mostrar modal de éxito elegante
        setTimeout(() => {
          setSuccessModal({
            show: true,
            message: 'Cobrador eliminado correctamente',
            nombre: nombreEliminado
          })
          
          // Auto-cerrar después de 2 segundos
          setTimeout(() => {
            setSuccessModal({ show: false, message: '' })
          }, 2000)
        }, 300)
      } else {
        throw new Error(result.error || 'Error eliminando cobrador')
      }
    } catch (error) {
      console.error('Error deleting cobrador:', error)
      alert('❌ Error al eliminar cobrador: ' + error.message)
    } finally {
      setDeleting(false)
    }
  }

  const getProgressColor = (current: number, meta: number) => {
    const percentage = (current / meta) * 100
    if (percentage >= 100) return 'from-green-500 to-green-600'
    if (percentage >= 75) return 'from-blue-500 to-blue-600'
    if (percentage >= 50) return 'from-amber-500 to-amber-600'
    return 'from-red-500 to-red-600'
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Cargando cobradores...</div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Gestión de Cobradores</h1>
          <p className="text-gray-500 mt-1">Administra tu equipo de cobradores</p>
        </div>
        
        <Link href="/cobradores/nuevo">
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl font-medium flex items-center gap-2 hover:from-blue-700 hover:to-blue-800 transition-all shadow-lg"
          >
            <Plus className="w-5 h-5" />
            Nuevo Cobrador
          </motion.button>
        </Link>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl shadow-lg p-6">
        <div className="flex flex-col md:flex-row gap-4">
          {/* Search */}
          <div className="flex-1 relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Buscar por nombre o teléfono..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            />
          </div>

          {/* Zona Filter */}
          <select
            value={filterZona}
            onChange={(e) => setFilterZona(e.target.value)}
            className="px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
            <option value="todos">Todas las zonas</option>
            <option value="norte">Zona Norte</option>
            <option value="sur">Zona Sur</option>
            <option value="centro">Zona Centro</option>
            <option value="este">Zona Este</option>
          </select>

          {/* Estado Filter */}
          <select
            value={filterEstado}
            onChange={(e) => setFilterEstado(e.target.value)}
            className="px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
            <option value="todos">Todos los estados</option>
            <option value="online">En línea</option>
            <option value="offline">Desconectado</option>
            <option value="sin_apk">Sin APK</option>
          </select>
        </div>
      </div>

      {/* Cobradores Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {cobradoresFiltrados.map((cobrador, index) => {
          const estadoVisual = getEstadoVisual(cobrador)
          const fechaFormateada = formatearFecha(cobrador.ultima_conexion)
          
          return (
            <motion.div
              key={cobrador.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              whileHover={{ y: -4 }}
              className="bg-white rounded-2xl shadow-lg hover:shadow-xl transition-all relative"
              style={{ overflow: 'visible' }}
            >
              {/* Header */}
              <div className="p-6 border-b border-gray-100">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-4">
                    <div className="w-16 h-16 bg-gradient-to-br from-gray-700 to-gray-900 rounded-xl flex items-center justify-center text-white font-bold text-xl">
                      {cobrador.nombre.split(' ').map(n => n[0]).join('').slice(0, 2)}
                    </div>
                    <div>
                      <h3 className="font-semibold text-gray-900">{cobrador.nombre}</h3>
                      <div className="flex items-center gap-2 text-sm text-gray-500 mt-1">
                        <Phone className="w-4 h-4" />
                        {cobrador.telefono}
                      </div>
                    </div>
                  </div>
                  <div className="relative menu-container">
                    <motion.button
                      whileHover={{ scale: 1.1 }}
                      whileTap={{ scale: 0.9 }}
                      onClick={(e) => {
                        e.preventDefault()
                        e.stopPropagation()
                        console.log('Menu clicked for:', cobrador.nombre) // Debug
                        setShowDeleteMenu(showDeleteMenu === cobrador.id ? null : cobrador.id)
                      }}
                      className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                      <MoreVertical className="w-5 h-5 text-gray-400" />
                    </motion.button>
                    
                    {showDeleteMenu === cobrador.id && (
                      <div 
                        className="absolute right-0 top-12 bg-white border-2 border-red-200 rounded-lg shadow-2xl min-w-[150px]"
                        style={{ zIndex: 9999 }}
                      >
                        <button
                          onClick={(e) => {
                            e.preventDefault()
                            e.stopPropagation()
                            openDeleteModal(cobrador.id, cobrador.nombre)
                          }}
                          className="w-full px-4 py-3 text-left text-red-600 hover:bg-red-50 rounded-lg transition-colors flex items-center gap-2 font-medium"
                        >
                          <Trash2 className="w-4 h-4" />
                          Eliminar
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm text-gray-600">
                    <MapPin className="w-4 h-4" />
                    {cobrador.zona_trabajo || 'Sin asignar'}
                  </div>
                  {getEstadoBadge(estadoVisual)}
                </div>
              </div>

              {/* Info */}
              <div className="p-6 bg-gray-50">
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">DNI:</span>
                    <span className="text-gray-700">{cobrador.dni}</span>
                  </div>
                  
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Total APKs:</span>
                    <span className="text-gray-700">{cobrador.total_builds || 0}</span>
                  </div>
                  
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-500">Última conexión:</span>
                    <span className="text-gray-700">{fechaFormateada}</span>
                  </div>
                  
                  {cobrador.ultimo_build_estado && (
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-gray-500">Último APK:</span>
                      <span className={`text-sm font-medium ${
                        cobrador.ultimo_build_estado === 'completed' ? 'text-green-600' : 
                        cobrador.ultimo_build_estado === 'failed' ? 'text-red-600' : 'text-amber-600'
                      }`}>
                        {cobrador.ultimo_build_estado}
                      </span>
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              <div className="p-4 bg-white border-t border-gray-100 flex gap-2">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="flex-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-lg font-medium text-sm flex items-center justify-center gap-1.5 hover:bg-gray-200 transition-colors"
                >
                  <Eye className="w-4 h-4" />
                  Ver
                </motion.button>
                
                {cobrador.apk_version && cobrador.ultimo_build_estado === 'completed' ? (
                  <>
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => downloadApk(cobrador.id, cobrador.nombre)}
                      className="flex-1 px-3 py-2 bg-blue-100 text-blue-700 rounded-lg font-medium text-sm flex items-center justify-center gap-1.5 hover:bg-blue-200 transition-colors"
                    >
                      <Download className="w-4 h-4" />
                      APK
                    </motion.button>
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      className="px-3 py-2 bg-amber-100 text-amber-700 rounded-lg font-medium text-sm flex items-center justify-center gap-1.5 hover:bg-amber-200 transition-colors"
                    >
                      <RefreshCw className="w-4 h-4" />
                    </motion.button>
                  </>
                ) : (
                  <Link href="/cobradores/nuevo" className="flex-1">
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      className="w-full px-3 py-2 bg-green-100 text-green-700 rounded-lg font-medium text-sm flex items-center justify-center gap-1.5 hover:bg-green-200 transition-colors"
                    >
                      <CheckCircle className="w-4 h-4" />
                      Generar APK
                    </motion.button>
                  </Link>
                )}
              </div>
            </motion.div>
          )
        })}
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Total Cobradores</h3>
          <p className="text-3xl font-bold mt-2">{cobradores.length}</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Con APK</h3>
          <p className="text-3xl font-bold mt-2">
            {cobradores.filter(c => c.apk_version && c.ultimo_build_estado === 'completed').length}
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-gradient-to-br from-amber-500 to-amber-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Sin APK</h3>
          <p className="text-3xl font-bold mt-2">
            {cobradores.filter(c => !c.apk_version || c.ultimo_build_estado !== 'completed').length}
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Total APKs</h3>
          <p className="text-3xl font-bold mt-2">
            {cobradores.reduce((sum, c) => sum + (c.total_builds || 0), 0)}
          </p>
        </motion.div>
      </div>

      {/* Modal de Confirmación Elegante - Renderizado con Portal */}
      {mounted && deleteModal && createPortal(
        <div 
          className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
          style={{ 
            zIndex: 999999,
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            width: '100vw',
            height: '100vh'
          }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            className="bg-white rounded-3xl shadow-2xl max-w-md w-full overflow-hidden relative"
            style={{ zIndex: 1000000 }}
          >
            {/* Header */}
            <div className="p-8 text-center">
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ delay: 0.1 }}
                className="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-6"
              >
                <Trash2 className="w-10 h-10 text-red-600" />
              </motion.div>
              
              <h3 className="text-2xl font-bold text-gray-900 mb-3">
                Eliminar Cobrador
              </h3>
              
              <p className="text-gray-600 mb-2">
                ¿Estás seguro de eliminar a <strong>{deleteModal.nombre}</strong>?
              </p>
              
              <div className="bg-red-50 rounded-xl p-4 mt-4">
                <p className="text-sm text-red-700 text-left">
                  <strong>Esta acción eliminará:</strong>
                </p>
                <ul className="text-sm text-red-600 mt-2 space-y-1 text-left">
                  <li>• El cobrador y su información</li>
                  <li>• Todo su historial de APKs</li>
                  <li>• Todos los archivos generados</li>
                </ul>
                <p className="text-sm text-red-800 font-medium mt-3 text-center">
                  ⚠️ Esta acción NO se puede deshacer
                </p>
              </div>
            </div>

            {/* Actions */}
            <div className="px-8 pb-8 flex gap-3">
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => setDeleteModal(null)}
                disabled={deleting}
                className="flex-1 px-6 py-3 bg-gray-100 text-gray-700 rounded-xl font-medium hover:bg-gray-200 transition-colors disabled:opacity-50"
              >
                Cancelar
              </motion.button>
              
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={deleteCobrador}
                disabled={deleting}
                className="flex-1 px-6 py-3 bg-red-600 text-white rounded-xl font-medium hover:bg-red-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {deleting ? (
                  <>
                    <motion.div
                      animate={{ rotate: 360 }}
                      transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                      className="w-4 h-4 border-2 border-white border-t-transparent rounded-full"
                    />
                    Eliminando...
                  </>
                ) : (
                  <>
                    <Trash2 className="w-4 h-4" />
                    Eliminar
                  </>
                )}
              </motion.button>
            </div>
          </motion.div>
        </div>,
        document.body
      )}

      {/* Modal de Éxito Elegante */}
      {mounted && successModal.show && createPortal(
        <div 
          className="fixed inset-0 bg-black/20 backdrop-blur-sm flex items-center justify-center p-4"
          style={{ 
            zIndex: 999999,
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            width: '100vw',
            height: '100vh'
          }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.8, y: 50 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.8, y: 50 }}
            className="bg-white rounded-3xl shadow-2xl max-w-sm w-full overflow-hidden relative"
            style={{ zIndex: 1000000 }}
          >
            {/* Header con gradiente verde */}
            <div className="bg-gradient-to-br from-green-500 to-green-600 p-8 text-center relative">
              {/* Botón cerrar */}
              <motion.button
                whileHover={{ scale: 1.1 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => setSuccessModal({ show: false, message: '' })}
                className="absolute top-4 right-4 p-2 bg-white/20 hover:bg-white/30 rounded-full transition-colors"
              >
                <X className="w-4 h-4 text-white" />
              </motion.button>

              {/* Icono de éxito animado */}
              <motion.div
                initial={{ scale: 0, rotate: -180 }}
                animate={{ scale: 1, rotate: 0 }}
                transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                className="w-20 h-20 bg-white rounded-full flex items-center justify-center mx-auto mb-4"
              >
                <Check className="w-10 h-10 text-green-600" />
              </motion.div>
              
              <motion.h3 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
                className="text-2xl font-bold text-white mb-2"
              >
                ¡Éxito!
              </motion.h3>
              
              <motion.p 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4 }}
                className="text-green-100"
              >
                {successModal.message}
              </motion.p>
            </div>

            {/* Contenido */}
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="p-6 text-center"
            >
              {successModal.nombre && (
                <div className="bg-green-50 rounded-xl p-4 mb-4">
                  <p className="text-green-800 font-medium">
                    <strong>{successModal.nombre}</strong> ha sido eliminado
                  </p>
                  <p className="text-sm text-green-600 mt-1">
                    Todos los datos asociados fueron removidos
                  </p>
                </div>
              )}
              
              {/* Barra de progreso de auto-cierre */}
              <div className="w-full bg-gray-200 rounded-full h-1 mb-4">
                <motion.div
                  initial={{ width: '100%' }}
                  animate={{ width: '0%' }}
                  transition={{ duration: 2, ease: "linear" }}
                  className="h-1 bg-gradient-to-r from-green-500 to-green-600 rounded-full"
                />
              </div>
              
              <p className="text-xs text-gray-500">
                Se cerrará automáticamente en 2 segundos
              </p>
            </motion.div>
          </motion.div>
        </div>,
        document.body
      )}
    </div>
  )
}