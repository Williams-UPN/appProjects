import { Octokit } from '@octokit/rest'

export class GitHubActionsBuilder {
  private octokit: Octokit | null = null
  private owner: string
  private repo: string
  
  constructor() {
    // Configurar solo si hay token disponible
    if (process.env.GITHUB_TOKEN) {
      this.octokit = new Octokit({
        auth: process.env.GITHUB_TOKEN
      })
    }
    
    this.owner = process.env.GITHUB_OWNER || 'tu-usuario'
    this.repo = process.env.GITHUB_REPO || 'admin-web'
  }
  
  async triggerBuild(config: {
    cobradorId: string
    nombre: string
    token: string
    credenciales: any
  }): Promise<{ id: number; url: string }> {
    
    if (!this.octokit) {
      throw new Error('GitHub Actions no configurado. Establece GITHUB_TOKEN en .env')
    }
    
    try {
      // Disparar workflow
      await this.octokit.rest.actions.createWorkflowDispatch({
        owner: this.owner,
        repo: this.repo,
        workflow_id: 'build-apk.yml',
        ref: 'main',
        inputs: {
          cobrador_id: config.cobradorId,
          nombre: config.nombre,
          token: config.token,
          credenciales: JSON.stringify(config.credenciales)
        }
      })
      
      // Esperar un momento para que se cree el workflow run
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Obtener el workflow run más reciente
      const { data: runs } = await this.octokit.rest.actions.listWorkflowRuns({
        owner: this.owner,
        repo: this.repo,
        workflow_id: 'build-apk.yml',
        per_page: 1
      })
      
      if (runs.workflow_runs.length > 0) {
        const run = runs.workflow_runs?.[0]
        return {
          id: run.id,
          url: run.html_url
        }
      }
      
      throw new Error('No se pudo obtener el workflow run')
      
    } catch (error) {
      console.error('[GitHubActions] Error:', error)
      throw error
    }
  }
  
  async checkStatus(workflowId: string): Promise<{
    completed: boolean
    success: boolean
    apkUrl?: string
    error?: string
  }> {
    
    if (!this.octokit) {
      return {
        completed: false,
        success: false,
        error: 'GitHub Actions no configurado'
      }
    }
    
    try {
      const { data: run } = await this.octokit.rest.actions.getWorkflowRun({
        owner: this.owner,
        repo: this.repo,
        run_id: parseInt(workflowId)
      })
      
      if (run.status === 'completed') {
        if (run.conclusion === 'success') {
          // Obtener artifacts
          const { data: artifacts } = await this.octokit.rest.actions.listWorkflowRunArtifacts({
            owner: this.owner,
            repo: this.repo,
            run_id: parseInt(workflowId)
          })
          
          const apkArtifact = artifacts.artifacts.find(a => a.name.includes('.apk'))
          
          return {
            completed: true,
            success: true,
            apkUrl: apkArtifact?.archive_download_url || undefined
          }
        } else {
          return {
            completed: true,
            success: false,
            error: `Workflow falló: ${run.conclusion}`
          }
        }
      }
      
      // Aún en progreso
      return {
        completed: false,
        success: false
      }
      
    } catch (error) {
      return {
        completed: false,
        success: false,
        error: error instanceof Error ? error.message : 'Error desconocido'
      }
    }
  }
  
  // Método para verificar si GitHub Actions está configurado
  isConfigured(): boolean {
    return !!this.octokit
  }
}

// Versión mock para desarrollo sin GitHub
export class GitHubActionsMock {
  async triggerBuild(config: any): Promise<{ id: number; url: string }> {
    console.log('[GitHubActionsMock] Simulando trigger de build')
    return {
      id: Math.floor(Math.random() * 1000000),
      url: 'https://github.com/mock/workflow/123'
    }
  }
  
  async checkStatus(workflowId: string): Promise<any> {
    console.log('[GitHubActionsMock] Simulando check de estado')
    // Simular que se completa después de 10 segundos
    const elapsed = Date.now() - parseInt(workflowId)
    
    if (elapsed > 10000) {
      return {
        completed: true,
        success: true,
        apkUrl: '/storage/generated/mock/app.apk'
      }
    }
    
    return {
      completed: false,
      success: false
    }
  }
  
  isConfigured(): boolean {
    return false
  }
}