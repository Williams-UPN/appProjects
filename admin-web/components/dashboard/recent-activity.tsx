'use client'

import { motion } from 'framer-motion'
import { Clock, MapPin, User, DollarSign } from 'lucide-react'
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
      ubicacion: 'Av. Principal 123'
    },
    {
      id: 2,
      type: 'payment',
      cliente: 'María López',
      cobrador: 'Ana Martínez',
      monto: 100,
      hora: '2024-01-17T10:15:00',
      ubicacion: 'Calle 5 #45'
    },
    {
      id: 3,
      type: 'new_client',
      cliente: 'Carlos Rodríguez',
      cobrador: 'Pedro García',
      monto: 1000,
      hora: '2024-01-17T09:45:00',
      ubicacion: 'Centro Comercial Plaza'
    },
    {
      id: 4,
      type: 'payment',
      cliente: 'Ana Silva',
      cobrador: 'Luis Mendoza',
      monto: 75,
      hora: '2024-01-17T09:30:00',
      ubicacion: 'Mercado Central'
    },
    {
      id: 5,
      type: 'note',
      cliente: 'Roberto Díaz',
      cobrador: 'Ana Martínez',
      monto: 0,
      hora: '2024-01-17T09:00:00',
      ubicacion: 'Tienda El Sol'
    }
  ]

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'payment':
        return <DollarSign className="w-5 h-5 text-green-600" />
      case 'new_client':
        return <User className="w-5 h-5 text-blue-600" />
      case 'note':
        return <Clock className="w-5 h-5 text-orange-600" />
      default:
        return <Clock className="w-5 h-5 text-gray-600" />
    }
  }

  const getActivityColor = (type: string) => {
    switch (type) {
      case 'payment':
        return 'bg-green-50 border-green-200'
      case 'new_client':
        return 'bg-blue-50 border-blue-200'
      case 'note':
        return 'bg-orange-50 border-orange-200'
      default:
        return 'bg-gray-50 border-gray-200'
    }
  }

  const getActivityText = (activity: any) => {
    switch (activity.type) {
      case 'payment':
        return `Cobro registrado: ${formatCurrency(activity.monto)}`
      case 'new_client':
        return `Nuevo cliente registrado`
      case 'note':
        return `Nota agregada: "Cliente no estaba"`
      default:
        return 'Actividad'
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.4 }}
      className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6"
    >
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-gray-900">Actividad Reciente</h2>
        <button className="text-sm text-primary-600 hover:text-primary-700 font-medium">
          Ver todo →
        </button>
      </div>

      <div className="space-y-4">
        {activities.map((activity, index) => (
          <motion.div
            key={activity.id}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: index * 0.1 }}
            className={`flex items-start gap-4 p-4 rounded-xl border ${getActivityColor(activity.type)}`}
          >
            <div className="flex-shrink-0 mt-1">
              {getActivityIcon(activity.type)}
            </div>
            
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1">
                  <p className="font-medium text-gray-900">{activity.cliente}</p>
                  <p className="text-sm text-gray-600 mt-1">
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
                
                <div className="text-right text-xs text-gray-500 flex-shrink-0">
                  <p>{new Date(activity.hora).toLocaleTimeString('es-PE', { 
                    hour: '2-digit', 
                    minute: '2-digit' 
                  })}</p>
                  <p className="mt-1">Hoy</p>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </motion.div>
  )
}