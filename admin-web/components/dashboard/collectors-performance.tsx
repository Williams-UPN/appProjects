'use client'

import { motion } from 'framer-motion'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts'
import { formatCurrency } from '@/lib/utils'
import { UserCheck, TrendingUp, Calendar, Trophy, Medal, Award } from 'lucide-react'

export default function CollectorsPerformance() {
  const data = [
    { name: 'Pedro G.', cobros: 4500, meta: 5000, color: '#3B82F6', rank: 2 },
    { name: 'Ana M.', cobros: 5200, meta: 5000, color: '#10B981', rank: 1 },
    { name: 'Luis M.', cobros: 3800, meta: 4000, color: '#F59E0B', rank: 4 },
    { name: 'María R.', cobros: 4200, meta: 4500, color: '#8B5CF6', rank: 3 },
    { name: 'Carlos S.', cobros: 3200, meta: 4000, color: '#EF4444', rank: 5 },
  ]

  const getRankIcon = (rank: number) => {
    switch(rank) {
      case 1: return <Trophy className="w-5 h-5 text-yellow-500" />
      case 2: return <Medal className="w-5 h-5 text-gray-400" />
      case 3: return <Award className="w-5 h-5 text-orange-600" />
      default: return null
    }
  }

  const CustomTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload
      const percentage = (data.cobros / data.meta) * 100
      return (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="bg-white/95 backdrop-blur-sm p-4 rounded-xl shadow-xl border border-gray-200"
        >
          <div className="flex items-center gap-2 mb-2">
            <p className="font-semibold text-gray-900">{data.name}</p>
            {getRankIcon(data.rank)}
          </div>
          <div className="space-y-1">
            <p className="text-sm text-gray-600">
              Cobros: <span className="font-bold text-gray-900">{formatCurrency(data.cobros)}</span>
            </p>
            <p className="text-sm text-gray-600">
              Meta: <span className="font-medium">{formatCurrency(data.meta)}</span>
            </p>
            <p className="text-sm font-medium" style={{ color: percentage >= 100 ? '#10B981' : '#F59E0B' }}>
              {percentage.toFixed(1)}% de la meta
            </p>
          </div>
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
      transition={{ delay: 0.3 }}
      className="bg-white rounded-2xl shadow-lg border border-gray-100 overflow-hidden hover:shadow-xl transition-all"
    >
      {/* Header with gradient */}
      <div className="bg-gradient-to-r from-indigo-500 to-purple-600 p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-white/20 backdrop-blur rounded-xl">
              <UserCheck className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-white">Rendimiento de Cobradores</h2>
              <p className="text-white/80 text-sm mt-0.5">Top 5 del día</p>
            </div>
          </div>
          <select className="text-sm bg-white/20 backdrop-blur border border-white/30 text-white rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-white/50">
            <option>Hoy</option>
            <option>Esta semana</option>
            <option>Este mes</option>
          </select>
        </div>
      </div>

      <div className="p-6">
        {/* Summary Stats */}
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="text-center p-3 bg-gray-50 rounded-xl">
            <p className="text-xs text-gray-500">Total Cobrado</p>
            <p className="text-lg font-bold text-gray-900 mt-1">
              {formatCurrency(data.reduce((sum, c) => sum + c.cobros, 0))}
            </p>
          </div>
          <div className="text-center p-3 bg-gray-50 rounded-xl">
            <p className="text-xs text-gray-500">Meta Total</p>
            <p className="text-lg font-bold text-gray-900 mt-1">
              {formatCurrency(data.reduce((sum, c) => sum + c.meta, 0))}
            </p>
          </div>
          <div className="text-center p-3 bg-gray-50 rounded-xl">
            <p className="text-xs text-gray-500">Cumplimiento</p>
            <p className="text-lg font-bold text-emerald-600 mt-1">
              {((data.reduce((sum, c) => sum + c.cobros, 0) / data.reduce((sum, c) => sum + c.meta, 0)) * 100).toFixed(0)}%
            </p>
          </div>
        </div>

        {/* Chart */}
        <div className="h-64 mb-6">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
              <defs>
                {data.map((entry, index) => (
                  <linearGradient key={`gradient-bar-${index}`} id={`gradient-bar-${index}`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={entry.color} stopOpacity={0.8} />
                    <stop offset="100%" stopColor={entry.color} stopOpacity={1} />
                  </linearGradient>
                ))}
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis 
                dataKey="name" 
                tick={{ fontSize: 12, fill: '#6b7280' }}
                axisLine={{ stroke: '#e5e7eb' }}
              />
              <YAxis 
                tick={{ fontSize: 12, fill: '#6b7280' }}
                axisLine={{ stroke: '#e5e7eb' }}
                tickFormatter={(value) => `$${value / 1000}k`}
              />
              <Tooltip content={<CustomTooltip />} cursor={{ fill: 'transparent' }} />
              <Bar 
                dataKey="cobros" 
                radius={[8, 8, 0, 0]}
                animationDuration={1000}
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={`url(#gradient-bar-${index})`} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Progress Bars with enhanced design */}
        <div className="space-y-3">
          {data.sort((a, b) => a.rank - b.rank).map((cobrador, index) => {
            const percentage = (cobrador.cobros / cobrador.meta) * 100
            return (
              <motion.div
                key={cobrador.name}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.4 + index * 0.1 }}
                whileHover={{ scale: 1.01 }}
                className="flex items-center gap-4 p-3 rounded-xl hover:bg-gray-50 transition-all"
              >
                <div className="flex items-center gap-3 w-28">
                  {getRankIcon(cobrador.rank)}
                  <span className="text-sm font-semibold text-gray-700">{cobrador.name}</span>
                </div>
                <div className="flex-1">
                  <div className="relative">
                    <div className="bg-gray-200 rounded-full h-3 overflow-hidden">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${Math.min(percentage, 100)}%` }}
                        transition={{ duration: 1, delay: 0.5 + index * 0.1 }}
                        className="h-full rounded-full relative overflow-hidden"
                        style={{ backgroundColor: cobrador.color }}
                      >
                        <div className="absolute inset-0 bg-white/20 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer" />
                      </motion.div>
                    </div>
                    {/* Meta line indicator */}
                    {percentage < 100 && (
                      <div className="absolute top-0 left-full h-full w-px bg-gray-400 -ml-px">
                        <div className="absolute -top-1 -left-2 text-xs text-gray-500 whitespace-nowrap">
                          Meta
                        </div>
                      </div>
                    )}
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-bold" style={{ color: cobrador.color }}>
                    {formatCurrency(cobrador.cobros)}
                  </p>
                  <p className="text-xs text-gray-500">{percentage.toFixed(0)}%</p>
                </div>
              </motion.div>
            )
          })}
        </div>
      </div>
    </motion.div>
  )
}