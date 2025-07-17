'use client'

import { motion } from 'framer-motion'
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts'
import { Users, TrendingUp, Eye } from 'lucide-react'

export default function ClientsChart() {
  const data = [
    { name: 'Al día', value: 85, color: '#3B82F6', gradient: 'from-blue-400 to-blue-600' },
    { name: 'Pendiente', value: 34, color: '#F59E0B', gradient: 'from-amber-400 to-amber-600' },
    { name: 'Atrasado', value: 23, color: '#EF4444', gradient: 'from-red-400 to-red-600' },
    { name: 'Completo', value: 14, color: '#10B981', gradient: 'from-emerald-400 to-emerald-600' },
  ]

  const total = data.reduce((sum, item) => sum + item.value, 0)

  const RADIAN = Math.PI / 180
  const renderCustomizedLabel = ({
    cx, cy, midAngle, innerRadius, outerRadius, percent
  }: any) => {
    const radius = innerRadius + (outerRadius - innerRadius) * 0.5
    const x = cx + radius * Math.cos(-midAngle * RADIAN)
    const y = cy + radius * Math.sin(-midAngle * RADIAN)

    return (
      <text 
        x={x} 
        y={y} 
        fill="white" 
        textAnchor={x > cx ? 'start' : 'end'} 
        dominantBaseline="central"
        className="font-bold text-sm"
      >
        {`${(percent * 100).toFixed(0)}%`}
      </text>
    )
  }

  const CustomTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0]
      return (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="bg-white/95 backdrop-blur-sm rounded-xl shadow-xl border border-gray-200 p-4"
        >
          <p className="font-semibold text-gray-900">{data.name}</p>
          <p className="text-2xl font-bold mt-1" style={{ color: data.payload.color }}>
            {data.value}
          </p>
          <p className="text-xs text-gray-500 mt-1">
            {((data.value / total) * 100).toFixed(1)}% del total
          </p>
        </motion.div>
      )
    }
    return null
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -2 }}
      transition={{ delay: 0.2 }}
      className="bg-white rounded-2xl shadow-lg border border-gray-100 overflow-hidden hover:shadow-xl transition-all"
    >
      {/* Header with gradient */}
      <div className="bg-gradient-to-r from-primary-500 to-primary-600 p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-white/20 backdrop-blur rounded-xl">
              <Users className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white">Estado de Clientes</h2>
              <p className="text-white/80 text-sm mt-0.5">Distribución actual</p>
            </div>
          </div>
          <button className="p-2 hover:bg-white/20 rounded-lg transition-colors">
            <Eye className="w-5 h-5 text-white" />
          </button>
        </div>
      </div>
      
      <div className="p-6">
        {/* Total counter */}
        <div className="text-center mb-6">
          <p className="text-sm text-gray-500">Total de clientes</p>
          <p className="text-4xl font-bold text-gray-900 mt-1">{total}</p>
          <div className="flex items-center justify-center gap-2 mt-2">
            <TrendingUp className="w-4 h-4 text-emerald-500" />
            <span className="text-sm text-emerald-600 font-medium">+12.5% este mes</span>
          </div>
        </div>

        {/* Chart */}
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <defs>
                {data.map((entry, index) => (
                  <linearGradient key={`gradient-${index}`} id={`gradient-${index}`}>
                    <stop offset="0%" stopColor={entry.color} stopOpacity={0.8} />
                    <stop offset="100%" stopColor={entry.color} stopOpacity={1} />
                  </linearGradient>
                ))}
              </defs>
              <Pie
                data={data}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={renderCustomizedLabel}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
                animationBegin={0}
                animationDuration={800}
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={`url(#gradient-${index})`} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Legend with enhanced styling */}
        <div className="mt-8 grid grid-cols-2 gap-4">
          {data.map((item, index) => (
            <motion.div
              key={item.name}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 + index * 0.1 }}
              whileHover={{ scale: 1.02 }}
              className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 transition-all cursor-pointer"
            >
              <div className={`w-12 h-12 bg-gradient-to-br ${item.gradient} rounded-lg shadow-md`} />
              <div className="flex-1">
                <p className="text-sm font-semibold text-gray-900">{item.name}</p>
                <p className="text-xs text-gray-500">{item.value} clientes</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-bold" style={{ color: item.color }}>
                  {((item.value / total) * 100).toFixed(0)}%
                </p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </motion.div>
  )
}