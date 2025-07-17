import { redirect } from 'next/navigation'

export default function DashboardRedirect() {
  // Redirige al dashboard principal (la raíz del layout protegido)
  redirect('/')
}