import { createClient } from '@/lib/supabase/server'
import StatsCards from '@/components/dashboard/stats-cards'
import RecentActivity from '@/components/dashboard/recent-activity'
import ClientsChart from '@/components/dashboard/clients-chart'
import CollectorsPerformance from '@/components/dashboard/collectors-performance'

export default async function DashboardPage() {
  const supabase = createClient()
  
  // Por ahora simulamos los datos, después los conectaremos a Supabase
  const stats = {
    total_clientes: 156,
    clientes_activos: 142,
    cobros_hoy: 8500,
    cobros_mes: 125000,
    clientes_atrasados: 23,
    tasa_cobro: 87
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 mt-1">Resumen general del sistema de cobros</p>
      </div>

      {/* Stats Cards */}
      <StatsCards stats={stats} />

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Clients Chart */}
        <ClientsChart />

        {/* Collectors Performance */}
        <CollectorsPerformance />
      </div>

      {/* Recent Activity */}
      <RecentActivity />
    </div>
  )
}