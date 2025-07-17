'use client'

import { Bell, Search, User, Clock, TrendingUp, AlertCircle } from 'lucide-react'
import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'

interface HeaderProps {
  user?: {
    nombre: string
    email: string
  }
}

export default function Header({ user }: HeaderProps) {
  const [showNotifications, setShowNotifications] = useState(false)
  const [currentTime, setCurrentTime] = useState(new Date())

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date())
    }, 1000)
    return () => clearInterval(timer)
  }, [])

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('es-ES', { 
      hour: '2-digit', 
      minute: '2-digit',
      second: '2-digit'
    })
  }

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('es-ES', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    })
  }

  const notifications = [
    {
      id: 1,
      type: 'success',
      icon: TrendingUp,
      color: 'bg-emerald-500',
      bgColor: 'bg-emerald-50',
      title: '5 nuevos cobros registrados',
      subtitle: 'Total: $3,500',
      time: 'Hace 10 minutos'
    },
    {
      id: 2,
      type: 'warning',
      icon: AlertCircle,
      color: 'bg-amber-500',
      bgColor: 'bg-amber-50',
      title: '15 clientes con pagos pendientes',
      subtitle: 'Vencen hoy',
      time: 'Hace 1 hora'
    },
    {
      id: 3,
      type: 'info',
      icon: User,
      color: 'bg-blue-500',
      bgColor: 'bg-blue-50',
      title: 'Nuevo cliente registrado',
      subtitle: 'Juan Pérez - Zona Norte',
      time: 'Hace 2 horas'
    }
  ]

  return (
    <header className="bg-white/80 backdrop-blur-lg border-b border-gray-200/50 px-6 py-4 sticky top-0 z-30">
      <div className="flex items-center justify-between">
        {/* Search with enhanced styling */}
        <div className="flex-1 max-w-xl">
          <motion.div 
            whileFocus={{ scale: 1.02 }}
            className="relative group"
          >
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-primary-500 transition-colors" />
            <input
              type="text"
              placeholder="Buscar clientes, cobros, cobradores..."
              className="w-full pl-12 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-primary-300/20 focus:border-primary-300 focus:bg-white transition-all placeholder:text-gray-400"
            />
            <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs text-gray-400 bg-gray-100 px-2 py-1 rounded-lg">
              ⌘K
            </div>
          </motion.div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-4 ml-6">
          {/* Live Time */}
          <div className="hidden lg:flex flex-col items-end px-4 border-r border-gray-200">
            <div className="flex items-center gap-2 text-sm font-medium text-gray-900">
              <Clock className="w-4 h-4 text-gray-400" />
              {formatTime(currentTime)}
            </div>
            <p className="text-xs text-gray-500 capitalize">{formatDate(currentTime)}</p>
          </div>

          {/* Notifications with badge */}
          <div className="relative">
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setShowNotifications(!showNotifications)}
              className="relative p-3 text-gray-600 hover:bg-gray-100 rounded-2xl transition-all"
            >
              <Bell className="w-5 h-5" />
              <motion.span 
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                className="absolute -top-1 -right-1 w-6 h-6 bg-gradient-to-r from-red-500 to-rose-600 text-white text-xs font-bold rounded-full flex items-center justify-center shadow-lg"
              >
                3
              </motion.span>
            </motion.button>

            <AnimatePresence>
              {showNotifications && (
                <>
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    onClick={() => setShowNotifications(false)}
                    className="fixed inset-0 z-40"
                  />
                  <motion.div
                    initial={{ opacity: 0, y: -10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: -10, scale: 0.95 }}
                    transition={{ type: "spring", damping: 25, stiffness: 300 }}
                    className="absolute right-0 mt-2 w-96 bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden z-50"
                  >
                    <div className="bg-gradient-to-r from-primary-500 to-primary-600 px-6 py-4">
                      <h3 className="font-semibold text-white text-lg">Notificaciones</h3>
                      <p className="text-white/80 text-sm">Tienes 3 nuevas alertas</p>
                    </div>
                    
                    <div className="max-h-96 overflow-y-auto">
                      {notifications.map((notification, index) => (
                        <motion.div
                          key={notification.id}
                          initial={{ opacity: 0, x: -20 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: index * 0.1 }}
                          className="p-4 border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer"
                        >
                          <div className="flex gap-4">
                            <div className={`w-12 h-12 ${notification.bgColor} rounded-xl flex items-center justify-center flex-shrink-0`}>
                              <notification.icon className={`w-6 h-6 ${notification.color.replace('bg-', 'text-')}`} />
                            </div>
                            <div className="flex-1">
                              <p className="text-sm font-medium text-gray-900">{notification.title}</p>
                              <p className="text-xs text-gray-600 mt-0.5">{notification.subtitle}</p>
                              <p className="text-xs text-gray-400 mt-1">{notification.time}</p>
                            </div>
                          </div>
                        </motion.div>
                      ))}
                    </div>
                    
                    <div className="p-4 bg-gray-50">
                      <button className="w-full py-2 text-sm font-medium text-primary-600 hover:text-primary-700 transition-colors">
                        Ver todas las notificaciones
                      </button>
                    </div>
                  </motion.div>
                </>
              )}
            </AnimatePresence>
          </div>

          {/* User Profile with enhanced styling */}
          <motion.div 
            whileHover={{ scale: 1.02 }}
            className="flex items-center gap-3 pl-4 border-l border-gray-200 cursor-pointer"
          >
            <div className="text-right">
              <p className="text-sm font-semibold text-gray-900">{user?.nombre || 'Administrador'}</p>
              <p className="text-xs text-gray-500">{user?.email || 'admin@sistema.com'}</p>
            </div>
            <div className="relative">
              <div className="w-12 h-12 bg-gradient-to-br from-primary-400 to-primary-600 rounded-2xl flex items-center justify-center shadow-lg">
                <User className="w-6 h-6 text-white" />
              </div>
              <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-emerald-500 border-2 border-white rounded-full"></div>
            </div>
          </motion.div>
        </div>
      </div>
    </header>
  )
}