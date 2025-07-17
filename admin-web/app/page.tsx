import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function Home() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  // Si hay usuario, mostramos el dashboard directamente
  const DashboardPage = (await import('./(dashboard)/page')).default
  return <DashboardPage />
}