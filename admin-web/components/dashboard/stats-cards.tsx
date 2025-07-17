'use client'

import { motion } from 'framer-motion'
import { Users, DollarSign, AlertCircle, TrendingUp, UserCheck, Calendar } from 'lucide-react'
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
      color: 'from-blue-400 to-blue-600',
      bgColor: 'bg-blue-50',
      textColor: 'text-blue-600',
      format: 'number'
    },
    {
      title: 'Cobros Hoy',
      value: stats.cobros_hoy,
      icon: DollarSign,
      color: 'from-green-400 to-green-600',
      bgColor: 'bg-green-50',
      textColor: 'text-green-600',
      format: 'currency'
    },
    {
      title: 'Clientes Atrasados',
      value: stats.clientes_atrasados,
      icon: AlertCircle,
      color: 'from-red-400 to-red-600',
      bgColor: 'bg-red-50',
      textColor: 'text-red-600',
      format: 'number'
    },
    {
      title: 'Tasa de Cobro',
      value: stats.tasa_cobro,
      icon: TrendingUp,
      color: 'from-purple-400 to-purple-600',
      bgColor: 'bg-purple-50',
      textColor: 'text-purple-600',
      format: 'percentage'
    },
    {
      title: 'Clientes Activos',
      value: stats.clientes_activos,
      icon: UserCheck,
      color: 'from-indigo-400 to-indigo-600',
      bgColor: 'bg-indigo-50',
      textColor: 'text-indigo-600',
      format: 'number'
    },
    {
      title: 'Cobros del Mes',
      value: stats.cobros_mes,
      icon: Calendar,
      color: 'from-amber-400 to-amber-600',
      bgColor: 'bg-amber-50',
      textColor: 'text-amber-600',
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

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
      {cards.map((card, index) => (
        <motion.div
          key={card.title}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: index * 0.1 }}
          className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 hover:shadow-lg transition-shadow"
        >
          <div className="flex items-center justify-between mb-4">
            <div className={`p-3 rounded-xl ${card.bgColor}`}>
              <card.icon className={`w-6 h-6 ${card.textColor}`} />
            </div>
            <div className={`w-2 h-2 rounded-full bg-gradient-to-r ${card.color}`}></div>
          </div>
          <h3 className="text-sm font-medium text-gray-600 mb-1">{card.title}</h3>
          <p className="text-2xl font-bold text-gray-900">
            {formatValue(card.value, card.format)}
          </p>
        </motion.div>
      ))}
    </div>
  )
}