import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

export function formatDate(date: string | Date): string {
  const d = new Date(date)
  return new Intl.DateTimeFormat('es-PE', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(d)
}

export function getStatusColor(status: string): string {
  const statusColors: Record<string, string> = {
    'al_dia': 'text-blue-600 bg-blue-100',
    'pendiente': 'text-orange-600 bg-orange-100',
    'atrasado': 'text-red-600 bg-red-100',
    'completo': 'text-green-600 bg-green-100',
    'proximo': 'text-gray-600 bg-gray-100',
  }
  return statusColors[status] || 'text-gray-600 bg-gray-100'
}

export function getStatusLabel(status: string): string {
  const statusLabels: Record<string, string> = {
    'al_dia': 'Al día',
    'pendiente': 'Pendiente',
    'atrasado': 'Atrasado',
    'completo': 'Completo',
    'proximo': 'Próximo',
  }
  return statusLabels[status] || status
}