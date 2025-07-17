'use client'

import { useState } from 'react'
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
  CheckCircle
} from 'lucide-react'

interface Cobrador {
  id: string
  nombre: string
  telefono: string
  zona: string
  estado: 'online' | 'offline' | 'sin_apk'
  apkVersion: string | null
  ultimaConexion: string
  cobrosHoy: number
  metaHoy: number
  foto?: string
}

export default function CobradoresPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [filterZona, setFilterZona] = useState('todos')
  const [filterEstado, setFilterEstado] = useState('todos')

  // Datos de ejemplo
  const cobradores: Cobrador[] = [
    {
      id: '1',
      nombre: 'Juan Carlos Pérez',
      telefono: '999888777',
      zona: 'Norte',
      estado: 'online',
      apkVersion: 'v1',
      ultimaConexion: 'Hace 5 min',
      cobrosHoy: 4500,
      metaHoy: 5000
    },
    {
      id: '2',
      nombre: 'María López',
      telefono: '987654321',
      zona: 'Sur',
      estado: 'offline',
      apkVersion: 'v1',
      ultimaConexion: 'Hace 2 horas',
      cobrosHoy: 3200,
      metaHoy: 4000
    },
    {
      id: '3',
      nombre: 'Carlos Ruiz',
      telefono: '912345678',
      zona: 'Centro',
      estado: 'sin_apk',
      apkVersion: null,
      ultimaConexion: 'Nunca',
      cobrosHoy: 0,
      metaHoy: 4500
    }
  ]

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

  const getProgressColor = (current: number, meta: number) => {
    const percentage = (current / meta) * 100
    if (percentage >= 100) return 'from-green-500 to-green-600'
    if (percentage >= 75) return 'from-blue-500 to-blue-600'
    if (percentage >= 50) return 'from-amber-500 to-amber-600'
    return 'from-red-500 to-red-600'
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
        {cobradores.map((cobrador, index) => {
          const progress = (cobrador.cobrosHoy / cobrador.metaHoy) * 100
          
          return (
            <motion.div
              key={cobrador.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              whileHover={{ y: -4 }}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-all"
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
                  <motion.button
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                    className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    <MoreVertical className="w-5 h-5 text-gray-400" />
                  </motion.button>
                </div>

                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm text-gray-600">
                    <MapPin className="w-4 h-4" />
                    Zona {cobrador.zona}
                  </div>
                  {getEstadoBadge(cobrador.estado)}
                </div>
              </div>

              {/* Progress */}
              <div className="p-6 bg-gray-50">
                <div className="mb-4">
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-600">Cobros del día</span>
                    <span className="font-medium text-gray-900">
                      S/ {cobrador.cobrosHoy.toLocaleString()} / {cobrador.metaHoy.toLocaleString()}
                    </span>
                  </div>
                  <div className="h-3 bg-gray-200 rounded-full overflow-hidden">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{ width: `${Math.min(progress, 100)}%` }}
                      transition={{ duration: 1, delay: 0.5 + index * 0.1 }}
                      className={`h-full bg-gradient-to-r ${getProgressColor(cobrador.cobrosHoy, cobrador.metaHoy)}`}
                    />
                  </div>
                  <p className="text-xs text-gray-500 mt-1 text-right">{progress.toFixed(0)}%</p>
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-500">Última conexión:</span>
                  <span className="text-gray-700">{cobrador.ultimaConexion}</span>
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
                
                {cobrador.apkVersion ? (
                  <>
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
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
          <h3 className="text-white/80 text-sm font-medium">En Línea</h3>
          <p className="text-3xl font-bold mt-2">
            {cobradores.filter(c => c.estado === 'online').length}
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-gradient-to-br from-amber-500 to-amber-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Cobro Total Hoy</h3>
          <p className="text-3xl font-bold mt-2">
            S/ {cobradores.reduce((sum, c) => sum + c.cobrosHoy, 0).toLocaleString()}
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-2xl p-6 text-white"
        >
          <h3 className="text-white/80 text-sm font-medium">Cumplimiento</h3>
          <p className="text-3xl font-bold mt-2">
            {Math.round(
              (cobradores.reduce((sum, c) => sum + c.cobrosHoy, 0) / 
               cobradores.reduce((sum, c) => sum + c.metaHoy, 0)) * 100
            )}%
          </p>
        </motion.div>
      </div>
    </div>
  )
}