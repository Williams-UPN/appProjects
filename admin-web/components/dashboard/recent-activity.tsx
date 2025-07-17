'use client'

import { motion } from 'framer-motion'
import { Clock, MapPin, User, DollarSign, UserPlus, FileText, TrendingUp, Activity } from 'lucide-react'
import { formatCurrency, formatDate } from '@/lib/utils'

export default function RecentActivity() {
  // Datos simulados por ahora
  const activities = [
    {
      id: 1,
      type: 'payment',
      cliente: 'Juan Pérez',
      cobrador: 'Pedro García',
      monto: 50,
      hora: '2024-01-17T10:30:00',
      ubicacion: 'Av. Principal 123',
      status: 'success'
    },
    {
      id: 2,
      type: 'payment',
      cliente: 'María López',
      cobrador: 'Ana Martínez',
      monto: 100,
      hora: '2024-01-17T10:15:00',
      ubicacion: 'Calle 5 #45',
      status: 'success'
    },
    {
      id: 3,
      type: 'new_client',
      cliente: 'Carlos Rodríguez',
      cobrador: 'Pedro García',
      monto: 1000,
      hora: '2024-01-17T09:45:00',
      ubicacion: 'Centro Comercial Plaza',
      status: 'info'
    },
    {
      id: 4,
      type: 'payment',
      cliente: 'Ana Silva',
      cobrador: 'Luis Mendoza',
      monto: 75,
      hora: '2024-01-17T09:30:00',
      ubicacion: 'Mercado Central',
      status: 'success'
    },
    {
      id: 5,
      type: 'note',
      cliente: 'Roberto Díaz',
      cobrador: 'Ana Martínez',
      monto: 0,
      hora: '2024-01-17T09:00:00',
      ubicacion: 'Tienda El Sol',
      status: 'warning'
    }
  ]

  const getActivityConfig = (type: string) => {
    switch (type) {
      case 'payment':
        return {
          icon: DollarSign,
          color: 'text-emerald-600',
          bgColor: 'bg-emerald-50',
          borderColor: 'border-emerald-200',
          gradient: 'from-emerald-400 to-emerald-600'
        }
      case 'new_client':
        return {
          icon: UserPlus,
          color: 'text-blue-600',
          bgColor: 'bg-blue-50',
          borderColor: 'border-blue-200',
          gradient: 'from-blue-400 to-blue-600'
        }
      case 'note':
        return {
          icon: FileText,
          color: 'text-amber-600',
          bgColor: 'bg-amber-50',
          borderColor: 'border-amber-200',
          gradient: 'from-amber-400 to-amber-600'
        }
      default:
        return {
          icon: Clock,
          color: 'text-gray-600',
          bgColor: 'bg-gray-50',
          borderColor: 'border-gray-200',
          gradient: 'from-gray-400 to-gray-600'
        }
    }
  }

  const getActivityText = (activity: any) => {
    switch (activity.type) {
      case 'payment':
        return `Cobro registrado: ${formatCurrency(activity.monto)}`
      case 'new_client':
        return `Nuevo cliente registrado - Préstamo inicial: ${formatCurrency(activity.monto)}`
      case 'note':
        return `Nota agregada: "Cliente no estaba"`
      default:
        return 'Actividad'
    }
  }

  const getTimeAgo = (date: string) => {
    const now = new Date()
    const past = new Date(date)
    const diff = now.getTime() - past.getTime()
    const minutes = Math.floor(diff / 60000)
    const hours = Math.floor(minutes / 60)
    
    if (minutes < 60) return `Hace ${minutes} min`
    if (hours < 24) return `Hace ${hours} h`
    return past.toLocaleDateString('es-ES')
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -2 }}
      transition={{ delay: 0.4 }}
      className="bg-white rounded-2xl shadow-lg border border-gray-100 overflow-hidden hover:shadow-xl transition-all"
    >
      {/* Header with gradient */}
      <div className="bg-gradient-to-r from-gray-700 to-gray-900 p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-white/20 backdrop-blur rounded-xl">
              <Activity className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white">Actividad Reciente</h2>
              <p className="text-white/80 text-sm mt-0.5">Últimas 5 operaciones</p>
            </div>
          </div>
          <motion.button 
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="text-sm bg-white/20 backdrop-blur text-white px-4 py-2 rounded-lg hover:bg-white/30 transition-all font-medium"
          >
            Ver todo →
          </motion.button>
        </div>
      </div>

      <div className="p-6">
        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="text-center p-3 bg-emerald-50 rounded-xl">
            <p className="text-2xl font-bold text-emerald-600">12</p>
            <p className="text-xs text-emerald-700">Cobros hoy</p>
          </div>
          <div className="text-center p-3 bg-blue-50 rounded-xl">
            <p className="text-2xl font-bold text-blue-600">3</p>
            <p className="text-xs text-blue-700">Nuevos clientes</p>
          </div>
          <div className="text-center p-3 bg-amber-50 rounded-xl">
            <p className="text-2xl font-bold text-amber-600">8</p>
            <p className="text-xs text-amber-700">Pendientes</p>
          </div>
        </div>

        {/* Activity Timeline */}
        <div className="relative">
          {/* Timeline line */}
          <div className="absolute left-6 top-8 bottom-8 w-0.5 bg-gray-200"></div>
          
          <div className="space-y-4">
            {activities.map((activity, index) => {
              const config = getActivityConfig(activity.type)
              const Icon = config.icon
              
              return (
                <motion.div
                  key={activity.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  whileHover={{ x: 4 }}
                  transition={{ delay: 0.5 + index * 0.1 }}
                  className="relative flex items-start gap-4 group"
                >
                  {/* Icon with gradient background */}
                  <div className="relative z-10">
                    <motion.div 
                      whileHover={{ scale: 1.1 }}
                      className={`w-12 h-12 rounded-xl bg-gradient-to-br ${config.gradient} flex items-center justify-center shadow-lg`}
                    >
                      <Icon className="w-6 h-6 text-white" />
                    </motion.div>
                    {/* Pulse animation for recent items */}
                    {index === 0 && (
                      <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 animate-ping opacity-20"></div>
                    )}
                  </div>
                  
                  {/* Content card */}
                  <div className={`flex-1 p-4 rounded-xl border ${config.borderColor} ${config.bgColor} group-hover:shadow-md transition-all`}>
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <p className="font-semibold text-gray-900">{activity.cliente}</p>
                          {activity.type === 'payment' && (
                            <TrendingUp className="w-4 h-4 text-emerald-500" />
                          )}
                        </div>
                        <p className={`text-sm ${config.color} mt-1 font-medium`}>
                          {getActivityText(activity)}
                        </p>
                        <div className="flex items-center gap-4 mt-2 text-xs text-gray-500">
                          <span className="flex items-center gap-1">
                            <User className="w-3 h-3" />
                            {activity.cobrador}
                          </span>
                          <span className="flex items-center gap-1">
                            <MapPin className="w-3 h-3" />
                            {activity.ubicacion}
                          </span>
                        </div>
                      </div>
                      
                      <div className="text-right flex-shrink-0">
                        <p className="text-xs font-medium text-gray-900">
                          {new Date(activity.hora).toLocaleTimeString('es-PE', { 
                            hour: '2-digit', 
                            minute: '2-digit' 
                          })}
                        </p>
                        <p className="text-xs text-gray-500 mt-1">
                          {getTimeAgo(activity.hora)}
                        </p>
                      </div>
                    </div>
                  </div>
                </motion.div>
              )
            })}
          </div>
        </div>
      </div>
    </motion.div>
  )
}