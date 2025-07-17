'use client'

import { motion } from 'framer-motion'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { formatCurrency } from '@/lib/utils'

export default function CollectorsPerformance() {
  const data = [
    { name: 'Pedro G.', cobros: 4500, meta: 5000 },
    { name: 'Ana M.', cobros: 5200, meta: 5000 },
    { name: 'Luis M.', cobros: 3800, meta: 4000 },
    { name: 'María R.', cobros: 4200, meta: 4500 },
    { name: 'Carlos S.', cobros: 3200, meta: 4000 },
  ]

  const CustomTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-white p-3 rounded-xl shadow-lg border border-gray-200">
          <p className="font-medium text-gray-900">{payload[0].payload.name}</p>
          <p className="text-sm text-green-600 mt-1">
            Cobros: {formatCurrency(payload[0].value)}
          </p>
          <p className="text-sm text-gray-500">
            Meta: {formatCurrency(payload[0].payload.meta)}
          </p>
        </div>
      )
    }
    return null
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 0.3 }}
      className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6"
    >
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-gray-900">Rendimiento de Cobradores</h2>
        <select className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-primary-300">
          <option>Hoy</option>
          <option>Esta semana</option>
          <option>Este mes</option>
        </select>
      </div>

      <div className="h-80">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 20, right: 30, left: 20, bottom: 5 }}>
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
            <Tooltip content={<CustomTooltip />} cursor={{ fill: '#f3f4f6' }} />
            <Bar 
              dataKey="cobros" 
              fill="#90CAF9"
              radius={[8, 8, 0, 0]}
              animationDuration={1000}
            />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="mt-6 space-y-3">
        {data.map((cobrador, index) => {
          const percentage = (cobrador.cobros / cobrador.meta) * 100
          return (
            <motion.div
              key={cobrador.name}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: index * 0.1 }}
              className="flex items-center gap-4"
            >
              <span className="text-sm font-medium text-gray-700 w-20">{cobrador.name}</span>
              <div className="flex-1">
                <div className="bg-gray-200 rounded-full h-2 overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${Math.min(percentage, 100)}%` }}
                    transition={{ duration: 1, delay: 0.5 + index * 0.1 }}
                    className={`h-full rounded-full ${
                      percentage >= 100 ? 'bg-green-500' : 'bg-primary-400'
                    }`}
                  />
                </div>
              </div>
              <span className="text-sm font-medium text-gray-900 w-12 text-right">
                {percentage.toFixed(0)}%
              </span>
            </motion.div>
          )
        })}
      </div>
    </motion.div>
  )
}