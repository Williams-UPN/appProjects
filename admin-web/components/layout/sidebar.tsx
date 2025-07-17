'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { 
  LayoutDashboard, 
  Users,
  UserPlus,
  UserCheck, 
  DollarSign, 
  FileText,
  LogOut,
  Menu,
  X,
  ChevronRight,
  MapPin,
  AlertCircle,
  Receipt,
  Wallet,
  TrendingUp,
  Calendar,
  FileBarChart,
  Settings,
  Plus,
  List,
  Route,
  BarChart3,
  Map,
  CircleDollarSign
} from 'lucide-react'
import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'

interface MenuItem {
  title: string
  href?: string
  icon: any
  badge?: string
  subItems?: MenuItem[]
}

const menuItems: MenuItem[] = [
  {
    title: 'Dashboard',
    href: '/',
    icon: LayoutDashboard,
  },
  {
    title: 'Gestión Clientes',
    icon: Users,
    subItems: [
      {
        title: 'Nuevo Cliente',
        href: '/clientes/nuevo',
        icon: UserPlus,
      },
      {
        title: 'Lista de Clientes',
        href: '/clientes',
        icon: List,
      },
      {
        title: 'Clientes Morosos',
        href: '/clientes/morosos',
        icon: AlertCircle,
        badge: '23'
      },
      {
        title: 'Mapa de Clientes',
        href: '/clientes/mapa',
        icon: Map,
      }
    ]
  },
  {
    title: 'Gestión Cobradores',
    icon: UserCheck,
    subItems: [
      {
        title: 'Nuevo Cobrador',
        href: '/cobradores/nuevo',
        icon: Plus,
      },
      {
        title: 'Lista Cobradores',
        href: '/cobradores',
        icon: List,
      },
      {
        title: 'Rutas del Día',
        href: '/cobradores/rutas',
        icon: Route,
      },
      {
        title: 'Rendimiento',
        href: '/cobradores/rendimiento',
        icon: BarChart3,
      }
    ]
  },
  {
    title: 'Finanzas',
    icon: DollarSign,
    subItems: [
      {
        title: 'Cobros del Día',
        href: '/finanzas/cobros',
        icon: Receipt,
      },
      {
        title: 'Gastos Registrados',
        href: '/finanzas/gastos',
        icon: Wallet,
      },
      {
        title: 'Balance General',
        href: '/finanzas/balance',
        icon: TrendingUp,
      },
      {
        title: 'Proyecciones',
        href: '/finanzas/proyecciones',
        icon: FileBarChart,
      }
    ]
  },
  {
    title: 'Reportes',
    icon: FileText,
    subItems: [
      {
        title: 'Reporte Diario',
        href: '/reportes/diario',
        icon: Calendar,
      },
      {
        title: 'Reporte Mensual',
        href: '/reportes/mensual',
        icon: FileBarChart,
      },
      {
        title: 'Por Cobrador',
        href: '/reportes/cobrador',
        icon: UserCheck,
      },
      {
        title: 'Por Zona',
        href: '/reportes/zona',
        icon: MapPin,
      }
    ]
  },
  {
    title: 'Configuración',
    href: '/configuracion',
    icon: Settings,
  }
]

export default function Sidebar() {
  const pathname = usePathname()
  const [isOpen, setIsOpen] = useState(false)
  const [expandedItems, setExpandedItems] = useState<string[]>(['Gestión Clientes'])
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  const toggleExpanded = (title: string) => {
    setExpandedItems(prev =>
      prev.includes(title)
        ? prev.filter(item => item !== title)
        : [...prev, title]
    )
  }

  const isActiveSection = (item: MenuItem): boolean => {
    if (item.href && pathname === item.href) return true
    if (item.subItems) {
      return item.subItems.some(sub => sub.href === pathname)
    }
    return false
  }

  // Don't render anything until mounted to avoid hydration issues
  if (!mounted) {
    return <div className="w-80 h-screen" />
  }

  return (
    <>
      {/* Mobile menu button - Minimal and elegant */}
      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => setIsOpen(!isOpen)}
        className="lg:hidden fixed top-4 left-4 z-50 p-3 bg-white/90 backdrop-blur-md rounded-2xl shadow-lg hover:shadow-xl transition-all duration-300"
      >
        {isOpen ? (
          <X className="w-5 h-5 text-gray-700" />
        ) : (
          <Menu className="w-5 h-5 text-gray-700" />
        )}
      </motion.button>

      {/* Mobile overlay with smooth fade */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setIsOpen(false)}
            className="lg:hidden fixed inset-0 bg-black/20 backdrop-blur-sm z-40"
          />
        )}
      </AnimatePresence>

      {/* Sidebar - Clean, minimal, beautiful */}
      <aside
        className={cn(
          "fixed lg:static inset-y-0 left-0 z-50 w-80 bg-white border-r border-gray-100 transition-transform duration-300 ease-in-out",
          isOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
        )}
      >
        <div className="flex flex-col h-full">
          {/* Logo section - Minimal and elegant */}
          <div className="p-8 border-b border-gray-100">
            <div className="flex items-center gap-4">
              <motion.div 
                whileHover={{ rotate: [0, -10, 10, -10, 0] }}
                transition={{ duration: 0.5 }}
                className="w-12 h-12 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg shadow-blue-500/20"
              >
                <CircleDollarSign className="w-7 h-7 text-white" />
              </motion.div>
              <div>
                <h2 className="text-xl font-semibold text-gray-900 tracking-tight">Sistema Cobros</h2>
                <p className="text-xs text-gray-500 font-medium">Panel Administrativo</p>
              </div>
            </div>
          </div>

          {/* Navigation - Clean with subtle interactions */}
          <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto scrollbar-thin">
            {menuItems.map((item) => {
              const isActive = isActiveSection(item)
              const isExpanded = expandedItems.includes(item.title)
              
              return (
                <div key={item.title}>
                  {item.href ? (
                    // Simple link with beautiful hover state
                    <Link
                      href={item.href}
                      onClick={() => setIsOpen(false)}
                      className="group relative"
                    >
                      <motion.div
                        whileHover={{ x: 4 }}
                        whileTap={{ scale: 0.98 }}
                        className={cn(
                          "flex items-center gap-3 px-4 py-3 rounded-2xl transition-all duration-200",
                          "hover:bg-gray-50",
                          isActive && "bg-blue-50"
                        )}
                      >
                        {/* Active indicator - Minimal dot */}
                        {isActive && (
                          <motion.div
                            layoutId="activeIndicator"
                            className="absolute left-0 w-1 h-8 bg-blue-500 rounded-full"
                            transition={{ type: "spring", damping: 30, stiffness: 300 }}
                          />
                        )}
                        
                        <item.icon className={cn(
                          "w-5 h-5 transition-colors duration-200",
                          isActive ? "text-blue-600" : "text-gray-400 group-hover:text-gray-600"
                        )} />
                        <span className={cn(
                          "font-medium transition-colors duration-200",
                          isActive ? "text-blue-600" : "text-gray-700 group-hover:text-gray-900"
                        )}>
                          {item.title}
                        </span>
                      </motion.div>
                    </Link>
                  ) : (
                    // Expandable section with smooth animation
                    <>
                      <motion.button
                        whileHover={{ x: 2 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => toggleExpanded(item.title)}
                        className={cn(
                          "w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition-all duration-200",
                          "hover:bg-gray-50",
                          isActive && "text-blue-600"
                        )}
                      >
                        <item.icon className={cn(
                          "w-5 h-5 transition-colors duration-200",
                          isActive ? "text-blue-600" : "text-gray-400"
                        )} />
                        <span className={cn(
                          "flex-1 text-left font-medium transition-colors duration-200",
                          isActive ? "text-blue-600" : "text-gray-700"
                        )}>
                          {item.title}
                        </span>
                        <motion.div
                          animate={{ rotate: isExpanded ? 90 : 0 }}
                          transition={{ duration: 0.2 }}
                        >
                          <ChevronRight className={cn(
                            "w-4 h-4 transition-colors duration-200",
                            isActive ? "text-blue-600" : "text-gray-400"
                          )} />
                        </motion.div>
                      </motion.button>
                      
                      <AnimatePresence>
                        {isExpanded && (
                          <motion.div
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: "auto", opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            transition={{ duration: 0.2 }}
                            className="overflow-hidden"
                          >
                            <div className="ml-4 mt-1 space-y-1 pb-2">
                              {item.subItems?.map((subItem) => {
                                const isSubActive = pathname === subItem.href
                                return (
                                  <Link
                                    key={subItem.href}
                                    href={subItem.href || '#'}
                                    onClick={() => setIsOpen(false)}
                                    className="group"
                                  >
                                    <motion.div
                                      whileHover={{ x: 4 }}
                                      whileTap={{ scale: 0.98 }}
                                      className={cn(
                                        "flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all duration-200",
                                        "hover:bg-gray-50",
                                        isSubActive && "bg-blue-50"
                                      )}
                                    >
                                      <div className={cn(
                                        "w-1.5 h-1.5 rounded-full transition-all duration-200",
                                        isSubActive ? "bg-blue-500 scale-125" : "bg-gray-300 group-hover:bg-gray-400"
                                      )} />
                                      <span className={cn(
                                        "text-sm transition-colors duration-200",
                                        isSubActive ? "font-medium text-blue-600" : "text-gray-600 group-hover:text-gray-900"
                                      )}>
                                        {subItem.title}
                                      </span>
                                      {subItem.badge && (
                                        <motion.span 
                                          initial={{ scale: 0 }}
                                          animate={{ scale: 1 }}
                                          className="ml-auto bg-red-500 text-white text-xs px-2 py-0.5 rounded-full font-medium"
                                        >
                                          {subItem.badge}
                                        </motion.span>
                                      )}
                                    </motion.div>
                                  </Link>
                                )
                              })}
                            </div>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </>
                  )}
                </div>
              )
            })}
          </nav>

          {/* User section - Minimal and clean */}
          <div className="p-4 border-t border-gray-100">
            <div className="p-4 bg-gray-50 rounded-2xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 bg-gradient-to-br from-gray-700 to-gray-900 rounded-xl flex items-center justify-center">
                  <span className="text-white font-semibold text-sm">A</span>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">Admin</p>
                  <p className="text-xs text-gray-500 truncate">admin@admin.com</p>
                </div>
              </div>
              <motion.button 
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-white rounded-xl text-gray-700 hover:text-red-600 hover:bg-red-50 transition-all duration-200 text-sm font-medium"
              >
                <LogOut className="w-4 h-4" />
                <span>Cerrar sesión</span>
              </motion.button>
            </div>
          </div>
        </div>
      </aside>
    </>
  )
}