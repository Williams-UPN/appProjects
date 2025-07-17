'use client'

import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'

export default function CreateTestUser() {
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')
  const supabase = createClient()

  const createUser = async () => {
    setLoading(true)
    try {
      const { data, error } = await supabase.auth.signUp({
        email: 'admin@test.com',
        password: '123456',
      })
      
      if (error) {
        setMessage('Error: ' + error.message)
      } else {
        setMessage('Usuario creado! Email: admin@test.com, Password: 123456')
      }
    } catch (err) {
      setMessage('Error al crear usuario')
    }
    setLoading(false)
  }

  return (
    <div className="mt-4 p-4 bg-gray-100 rounded-xl">
      <p className="text-sm text-gray-600 mb-2">¿Primera vez? Crea un usuario de prueba:</p>
      <button
        onClick={createUser}
        disabled={loading}
        className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 disabled:opacity-50"
      >
        {loading ? 'Creando...' : 'Crear usuario de prueba'}
      </button>
      {message && (
        <p className="mt-2 text-sm text-gray-700">{message}</p>
      )}
    </div>
  )
}