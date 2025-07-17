'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { 
  Search, 
  Filter, 
  Plus, 
  MapPin, 
  Phone, 
  Store,
  Star,
  MoreVertical
} from 'lucide-react'
import { getStatusColor, getStatusLabel, formatCurrency } from '@/lib/utils'

export default function ClientesPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState('todos')

  // Datos simulados
  const clientes = [
    {
      id: 1,
      nombre: 'Juan Pérez',
      telefono: '555-0123',
      negocio: 'Tienda La Esquina',
      direccion: 'Av. Principal 123',
      monto_solicitado: 1000,
      saldo_pendiente: 750,
      estado: 'al_dia',
      score: 85,
      cobrador: 'Pedro García'
    },
    {
      id: 2,
      nombre: 'María López',
      telefono: '555-0124',
      negocio: 'Restaurant El Sabor',
      direccion: 'Calle 5 #45',
      monto_solicitado: 2000,
      saldo_pendiente: 1800,
      estado: 'pendiente',
      score: 72,
      cobrador: 'Ana Martínez'
    },
    {
      id: 3,
      nombre: 'Carlos Rodríguez',
      telefono: '555-0125',
      negocio: 'Ferretería Central',
      direccion: 'Plaza Mayor 10',
      monto_solicitado: 1500,
      saldo_pendiente: 1500,
      estado: 'atrasado',
      score: 45,
      cobrador: 'Luis Mendoza'
    },
    {
      id: 4,
      nombre: 'Ana Silva',
      telefono: '555-0126',
      negocio: 'Boutique Fashion',
      direccion: 'Centro Comercial Local 25',
      monto_solicitado: 800,
      saldo_pendiente: 0,
      estado: 'completo',
      score: 95,
      cobrador: 'Pedro García'
    },
    {
      id: 5,
      nombre: 'Roberto Díaz',
      telefono: '555-0127',
      negocio: 'Taller Mecánico RD',
      direccion: 'Zona Industrial 8',
      monto_solicitado: 3000,
      saldo_pendiente: 2500,
      estado: 'al_dia',
      score: 78,
      cobrador: 'Ana Martínez'
    }
  ]

  const filteredClientes = clientes.filter(cliente => {
    const matchesSearch = cliente.nombre.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         cliente.negocio.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         cliente.telefono.includes(searchTerm)
    
    const matchesFilter = filterStatus === 'todos' || cliente.estado === filterStatus
    
    return matchesSearch && matchesFilter
  })

  const getScoreStars = (score: number) => {
    const stars = Math.round(score / 20)
    return Array(5).fill(0).map((_, i) => (
      <Star 
        key={i} 
        className={`w-4 h-4 ${i < stars ? 'text-amber-400 fill-amber-400' : 'text-gray-300'}`} 
      />
    ))
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Clientes</h1>
          <p className="text-gray-500 mt-1">Gestiona todos los clientes del sistema</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl hover:bg-primary-300 transition-colors">
          <Plus className="w-5 h-5" />
          Nuevo Cliente
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <div className="flex flex-col md:flex-row gap-4">
          {/* Search */}
          <div className="flex-1">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por nombre, negocio o teléfono..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300 focus:border-transparent transition-all"
              />
            </div>
          </div>

          {/* Status Filter */}
          <div className="flex items-center gap-2">
            <Filter className="w-5 h-5 text-gray-500" />
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="px-4 py-2 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary-300"
            >
              <option value="todos">Todos</option>
              <option value="al_dia">Al día</option>
              <option value="pendiente">Pendiente</option>
              <option value="atrasado">Atrasado</option>
              <option value="completo">Completo</option>
            </select>
          </div>
        </div>
      </div>

      {/* Clients Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredClientes.map((cliente, index) => (
          <motion.div
            key={cliente.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 hover:shadow-lg transition-all cursor-pointer"
          >
            {/* Header */}
            <div className="flex items-start justify-between mb-4">
              <div>
                <h3 className="font-semibold text-gray-900 text-lg">{cliente.nombre}</h3>
                <p className="text-sm text-gray-500 flex items-center gap-1 mt-1">
                  <Store className="w-4 h-4" />
                  {cliente.negocio}
                </p>
              </div>
              <button className="p-1 hover:bg-gray-100 rounded-lg transition-colors">
                <MoreVertical className="w-5 h-5 text-gray-500" />
              </button>
            </div>

            {/* Status Badge */}
            <div className="mb-4">
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(cliente.estado)}`}>
                {getStatusLabel(cliente.estado)}
              </span>
            </div>

            {/* Info */}
            <div className="space-y-3 mb-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-500">Préstamo</span>
                <span className="font-medium">{formatCurrency(cliente.monto_solicitado)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-500">Saldo</span>
                <span className="font-medium text-orange-600">{formatCurrency(cliente.saldo_pendiente)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-500">Cobrador</span>
                <span className="text-sm font-medium">{cliente.cobrador}</span>
              </div>
            </div>

            {/* Rating */}
            <div className="flex items-center justify-between pt-4 border-t border-gray-100">
              <div className="flex items-center gap-1">
                {getScoreStars(cliente.score)}
              </div>
              <div className="flex items-center gap-3 text-sm text-gray-500">
                <span className="flex items-center gap-1">
                  <Phone className="w-4 h-4" />
                  {cliente.telefono}
                </span>
                <span className="flex items-center gap-1">
                  <MapPin className="w-4 h-4" />
                  GPS
                </span>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  )
}