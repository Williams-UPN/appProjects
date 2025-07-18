'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { 
  ArrowLeft, 
  ArrowRight,
  User,
  MapPin,
  Phone,
  Store,
  DollarSign,
  Calendar,
  Calculator,
  Check,
  X
} from 'lucide-react'
import Link from 'next/link'

export default function NuevoClientePage() {
  const [currentStep, setCurrentStep] = useState(1)
  const [showMap, setShowMap] = useState(false)
  
  // Form data
  const [formData, setFormData] = useState({
    nombre: '',
    telefono: '',
    negocio: '',
    direccion: '',
    monto: '',
    plazo: 12,
    fechaPrimerPago: new Date().toISOString().split('T')[0]
  })

  // Calculations
  const calculateLoan = () => {
    const amount = parseFloat(formData.monto) || 0
    const days = formData.plazo
    const interestRate = days === 12 ? 0.10 : 0.20
    const interest = amount * interestRate
    const total = amount + interest
    const dailyPayment = Math.ceil(total / days)
    const lastPayment = total - (dailyPayment * (days - 1))
    
    return {
      amount,
      interest,
      total,
      dailyPayment,
      lastPayment
    }
  }

  const loan = calculateLoan()

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    })
  }

  const handleNext = () => {
    if (currentStep < 2) {
      setCurrentStep(currentStep + 1)
    }
  }

  const handleBack = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Link 
                href="/clientes" 
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <ArrowLeft className="w-5 h-5" />
              </Link>
              <h1 className="text-2xl font-bold text-gray-900">Nuevo Cliente</h1>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-500">Paso</span>
              <span className="text-sm font-semibold text-blue-600">{currentStep}/2</span>
            </div>
          </div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-6xl mx-auto px-6 py-2">
          <div className="flex gap-2">
            <div className={`h-1 flex-1 rounded-full transition-colors ${
              currentStep >= 1 ? 'bg-blue-600' : 'bg-gray-200'
            }`} />
            <div className={`h-1 flex-1 rounded-full transition-colors ${
              currentStep >= 2 ? 'bg-blue-600' : 'bg-gray-200'
            }`} />
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-4xl mx-auto px-6 py-8">
        <AnimatePresence mode="wait">
          {currentStep === 1 ? (
            <motion.div
              key="step1"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="space-y-6"
            >
              {/* Client Information */}
              <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                    <User className="w-5 h-5 text-blue-600" />
                  </div>
                  <h2 className="text-xl font-semibold text-gray-900">Información del Cliente</h2>
                </div>

                <div className="grid gap-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Nombre completo
                    </label>
                    <input
                      type="text"
                      name="nombre"
                      value={formData.nombre}
                      onChange={handleInputChange}
                      className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                      placeholder="Ingrese el nombre completo"
                    />
                  </div>

                  <div className="grid md:grid-cols-2 gap-6">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        <Phone className="w-4 h-4 inline mr-1" />
                        Teléfono
                      </label>
                      <input
                        type="tel"
                        name="telefono"
                        value={formData.telefono}
                        onChange={handleInputChange}
                        className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                        placeholder="999 999 999"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        <Store className="w-4 h-4 inline mr-1" />
                        Tipo de Negocio
                      </label>
                      <input
                        type="text"
                        name="negocio"
                        value={formData.negocio}
                        onChange={handleInputChange}
                        className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                        placeholder="Ej: Restaurante, Tienda, etc."
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Location */}
              <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                    <MapPin className="w-5 h-5 text-green-600" />
                  </div>
                  <h2 className="text-xl font-semibold text-gray-900">Ubicación del Negocio</h2>
                </div>

                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Dirección
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        name="direccion"
                        value={formData.direccion}
                        onChange={handleInputChange}
                        className="w-full px-4 py-3 pr-12 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                        placeholder="Ingrese la dirección del negocio"
                      />
                      <button
                        onClick={() => setShowMap(!showMap)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 p-2 hover:bg-gray-100 rounded-lg transition-colors"
                      >
                        <MapPin className="w-5 h-5 text-gray-500" />
                      </button>
                    </div>
                  </div>

                  {showMap && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                      className="overflow-hidden"
                    >
                      <div className="h-64 bg-gray-100 rounded-xl flex items-center justify-center relative">
                        <div className="text-center">
                          <MapPin className="w-12 h-12 text-gray-400 mx-auto mb-2" />
                          <p className="text-gray-500">Mapa interactivo</p>
                          <p className="text-sm text-gray-400">Implementación pendiente</p>
                        </div>
                        <div className="absolute bottom-4 left-4 right-4 flex gap-2">
                          <button className="flex-1 px-4 py-2 bg-white border border-gray-300 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors">
                            Usar mi ubicación
                          </button>
                          <button className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors">
                            Confirmar ubicación
                          </button>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key="step2"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="space-y-6"
            >
              {/* Loan Details */}
              <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
                    <DollarSign className="w-5 h-5 text-amber-600" />
                  </div>
                  <h2 className="text-xl font-semibold text-gray-900">Detalles del Préstamo</h2>
                </div>

                <div className="grid gap-6">
                  <div className="grid md:grid-cols-2 gap-6">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Monto Solicitado
                      </label>
                      <div className="relative">
                        <span className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500">S/.</span>
                        <input
                          type="number"
                          name="monto"
                          value={formData.monto}
                          onChange={handleInputChange}
                          className="w-full pl-12 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                          placeholder="0.00"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Plazo
                      </label>
                      <div className="grid grid-cols-2 gap-2">
                        <button
                          onClick={() => setFormData({ ...formData, plazo: 12 })}
                          className={`px-4 py-3 rounded-xl font-medium transition-all ${
                            formData.plazo === 12
                              ? 'bg-blue-600 text-white'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                          }`}
                        >
                          12 días
                        </button>
                        <button
                          onClick={() => setFormData({ ...formData, plazo: 24 })}
                          className={`px-4 py-3 rounded-xl font-medium transition-all ${
                            formData.plazo === 24
                              ? 'bg-blue-600 text-white'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                          }`}
                        >
                          24 días
                        </button>
                      </div>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      <Calendar className="w-4 h-4 inline mr-1" />
                      Primera fecha de pago
                    </label>
                    <input
                      type="date"
                      name="fechaPrimerPago"
                      value={formData.fechaPrimerPago}
                      onChange={handleInputChange}
                      className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                    />
                  </div>
                </div>
              </div>

              {/* Calculation Summary */}
              <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
                <div className="flex items-center gap-3 mb-6">
                  <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                    <Calculator className="w-5 h-5 text-purple-600" />
                  </div>
                  <h2 className="text-xl font-semibold text-gray-900">Resumen de Cálculo</h2>
                </div>

                <div className="bg-gray-50 rounded-xl p-6 space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-600">Monto solicitado:</span>
                    <span className="font-semibold text-gray-900">S/. {loan.amount.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-gray-600">Interés ({formData.plazo === 12 ? '10%' : '20%'}):</span>
                    <span className="font-semibold text-gray-900">S/. {loan.interest.toFixed(2)}</span>
                  </div>
                  <div className="border-t border-gray-200 pt-4">
                    <div className="flex justify-between items-center text-lg">
                      <span className="font-semibold text-gray-900">Total a pagar:</span>
                      <span className="font-bold text-blue-600">S/. {loan.total.toFixed(2)}</span>
                    </div>
                  </div>
                  <div className="border-t border-gray-200 pt-4 space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Cuota diaria:</span>
                      <span className="font-semibold text-gray-900">S/. {loan.dailyPayment.toFixed(2)}</span>
                    </div>
                    {loan.lastPayment !== loan.dailyPayment && (
                      <div className="flex justify-between items-center">
                        <span className="text-gray-600">Última cuota:</span>
                        <span className="font-semibold text-gray-900">S/. {loan.lastPayment.toFixed(2)}</span>
                      </div>
                    )}
                  </div>
                  <div className="border-t border-gray-200 pt-4 space-y-2 text-sm">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Fecha primer pago:</span>
                      <span className="font-medium text-gray-900">
                        {new Date(formData.fechaPrimerPago).toLocaleDateString('es-ES', {
                          day: '2-digit',
                          month: '2-digit',
                          year: 'numeric'
                        })}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Fecha último pago:</span>
                      <span className="font-medium text-gray-900">
                        {new Date(
                          new Date(formData.fechaPrimerPago).getTime() + 
                          (formData.plazo - 1) * 24 * 60 * 60 * 1000
                        ).toLocaleDateString('es-ES', {
                          day: '2-digit',
                          month: '2-digit',
                          year: 'numeric'
                        })}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Navigation Buttons */}
        <div className="flex justify-between items-center mt-8">
          <button
            onClick={handleBack}
            className={`flex items-center gap-2 px-6 py-3 rounded-xl font-medium transition-all ${
              currentStep === 1
                ? 'text-gray-400 cursor-not-allowed'
                : 'text-gray-700 hover:bg-gray-100'
            }`}
            disabled={currentStep === 1}
          >
            <ArrowLeft className="w-5 h-5" />
            Anterior
          </button>

          {currentStep === 1 ? (
            <button
              onClick={handleNext}
              className="flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-xl font-medium hover:bg-blue-700 transition-all"
            >
              Siguiente
              <ArrowRight className="w-5 h-5" />
            </button>
          ) : (
            <button
              className="flex items-center gap-2 px-6 py-3 bg-green-600 text-white rounded-xl font-medium hover:bg-green-700 transition-all"
            >
              <Check className="w-5 h-5" />
              Crear Cliente
            </button>
          )}
        </div>
      </div>
    </div>
  )
}