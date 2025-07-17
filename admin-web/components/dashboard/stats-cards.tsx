'use client'

import { motion } from 'framer-motion'
import { Users, DollarSign, AlertCircle, TrendingUp, UserCheck, Calendar, ArrowUp, ArrowDown, Minus } from 'lucide-react'
import { formatCurrency } from '@/lib/utils'

interface StatsCardsProps {
  stats: {
    total_clientes: number
    clientes_activos: number
    cobros_hoy: number
    cobros_mes: number
    clientes_atrasados: number
    tasa_cobro: number
  }
}

export default function StatsCards({ stats }: StatsCardsProps) {
  const cards = [
    {
      title: 'Total Clientes',
      value: stats.total_clientes,
      icon: Users,
      gradient: 'from-blue-500 to-blue-600',
      shadowColor: 'shadow-blue-500/20',
      change: 12,
      changeType: 'increase',
      sparklineData: [65, 59, 80, 81, 56, 55, 78, 80, 85, 92, 95, 98],
      format: 'number'
    },
    {
      title: 'Cobros Hoy',
      value: stats.cobros_hoy,
      icon: DollarSign,
      gradient: 'from-emerald-500 to-green-600',
      shadowColor: 'shadow-emerald-500/20',
      change: 8.5,
      changeType: 'increase',
      sparklineData: [30, 40, 45, 50, 49, 60, 70, 75, 80, 82, 85, 87],
      format: 'currency'
    },
    {
      title: 'Clientes Atrasados',
      value: stats.clientes_atrasados,
      icon: AlertCircle,
      gradient: 'from-red-500 to-rose-600',
      shadowColor: 'shadow-red-500/20',
      change: 3.2,
      changeType: 'decrease',
      sparklineData: [90, 85, 82, 78, 75, 73, 70, 68, 65, 63, 60, 58],
      format: 'number'
    },
    {
      title: 'Tasa de Cobro',
      value: stats.tasa_cobro,
      icon: TrendingUp,
      gradient: 'from-purple-500 to-violet-600',
      shadowColor: 'shadow-purple-500/20',
      change: 2.4,
      changeType: 'increase',
      sparklineData: [82, 83, 84, 85, 84, 86, 87, 86, 87, 88, 87, 89],
      format: 'percentage'
    },
    {
      title: 'Clientes Activos',
      value: stats.clientes_activos,
      icon: UserCheck,
      gradient: 'from-indigo-500 to-indigo-600',
      shadowColor: 'shadow-indigo-500/20',
      change: 0,
      changeType: 'neutral',
      sparklineData: [140, 141, 142, 142, 141, 142, 143, 142, 141, 142, 142, 142],
      format: 'number'
    },
    {
      title: 'Cobros del Mes',
      value: stats.cobros_mes,
      icon: Calendar,
      gradient: 'from-amber-500 to-orange-600',
      shadowColor: 'shadow-amber-500/20',
      change: 15.3,
      changeType: 'increase',
      sparklineData: [95, 98, 102, 105, 108, 112, 115, 118, 120, 122, 123, 125],
      format: 'currency'
    }
  ]

  const formatValue = (value: number, format: string) => {
    switch (format) {
      case 'currency':
        return formatCurrency(value)
      case 'percentage':
        return `${value}%`
      default:
        return value.toLocaleString()
    }
  }

  const renderSparkline = (data: number[]) => {
    const max = Math.max(...data)
    const min = Math.min(...data)
    const range = max - min
    const points = data.map((value, index) => {
      const x = (index / (data.length - 1)) * 100
      const y = 100 - ((value - min) / range) * 100
      return `${x},${y}`
    }).join(' ')
    
    return (
      <svg className="w-full h-12" viewBox="0 0 100 100" preserveAspectRatio="none">
        <polyline
          points={points}
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          className="text-white/50"
          vectorEffect="non-scaling-stroke"
        />
        <polyline
          points={`0,100 ${points} 100,100`}
          fill="currentColor"
          className="text-white/10"
        />
      </svg>
    )
  }

  const getChangeIcon = (changeType: string) => {
    switch (changeType) {
      case 'increase':
        return <ArrowUp className="w-4 h-4" />
      case 'decrease':
        return <ArrowDown className="w-4 h-4" />
      default:
        return <Minus className="w-4 h-4" />
    }
  }

  const getChangeColor = (changeType: string) => {
    switch (changeType) {
      case 'increase':
        return 'text-emerald-400 bg-emerald-400/20'
      case 'decrease':
        return 'text-red-400 bg-red-400/20'
      default:
        return 'text-gray-400 bg-gray-400/20'
    }
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
      {cards.map((card, index) => (
        <motion.div
          key={card.title}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          whileHover={{ scale: 1.02, y: -2 }}
          transition={{ 
            delay: index * 0.05,
            duration: 0.3,
            type: "spring",
            stiffness: 200
          }}
          className={`relative overflow-hidden bg-gradient-to-br ${card.gradient} rounded-2xl shadow-lg ${card.shadowColor} hover:shadow-xl transition-all cursor-pointer`}
        >
          <div className="absolute inset-0 bg-white/5 backdrop-blur-sm" />
          
          {/* Background Pattern */}
          <div className="absolute -right-8 -top-8 w-32 h-32 bg-white/10 rounded-full blur-2xl" />
          <div className="absolute -left-8 -bottom-8 w-32 h-32 bg-white/10 rounded-full blur-2xl" />
          
          {/* Sparkline */}
          <div className="absolute bottom-0 left-0 right-0 h-16 opacity-60">
            {renderSparkline(card.sparklineData)}
          </div>
          
          <div className="relative p-6 z-10">
            <div className="flex items-start justify-between mb-4">
              <div className="p-3 bg-white/20 backdrop-blur rounded-xl">
                <card.icon className="w-6 h-6 text-white" />
              </div>
              
              {/* Change Indicator */}
              <div className={`flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${getChangeColor(card.changeType)}`}>
                {getChangeIcon(card.changeType)}
                <span>{Math.abs(card.change)}%</span>
              </div>
            </div>
            
            <h3 className="text-sm font-medium text-white/80 mb-1">{card.title}</h3>
            <p className="text-2xl font-bold text-white">
              {formatValue(card.value, card.format)}
            </p>
          </div>
        </motion.div>
      ))}
    </div>
  )
}