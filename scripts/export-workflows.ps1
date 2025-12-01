# Export n8n Workflows Script
# Ce script exporte tous les workflows n8n actifs vers le dossier workflows/

param(
    [string]$Environment = "production",
    [string]$N8nHost = "http://localhost:3000"
)

# Charger les variables d'environnement depuis .env
if (Test-Path ".env") {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^([^=#]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

# Configuration
$N8N_USER = $env:N8N_BASIC_AUTH_USER
$N8N_PASSWORD = $env:N8N_BASIC_AUTH_PASSWORD
$EXPORT_DIR = "./workflows/$Environment"

Write-Host "🚀 Export des workflows n8n" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Host: $N8nHost" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host "Export dir: $EXPORT_DIR" -ForegroundColor Gray
Write-Host ""

# Vérifier que n8n est accessible
try {
    $null = Invoke-WebRequest -Uri $N8nHost -Method Head -TimeoutSec 5 -ErrorAction Stop
} catch {
    Write-Host "❌ Erreur: n8n n'est pas accessible sur $N8nHost" -ForegroundColor Red
    Write-Host "   Assurez-vous que n8n est démarré avec 'docker compose up -d'" -ForegroundColor Yellow
    exit 1
}

# Vérifier les credentials
if (-not $N8N_USER -or -not $N8N_PASSWORD) {
    Write-Host "❌ Erreur: N8N_BASIC_AUTH_USER ou N8N_BASIC_AUTH_PASSWORD non défini" -ForegroundColor Red
    Write-Host "   Vérifiez votre fichier .env" -ForegroundColor Yellow
    exit 1
}

# Créer le dossier s'il n'existe pas
New-Item -ItemType Directory -Force -Path $EXPORT_DIR | Out-Null

# Créer les credentials en base64
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${N8N_USER}:${N8N_PASSWORD}"))

# Headers pour l'API
$headers = @{
    "Authorization" = "Basic $credentials"
    "Accept" = "application/json"
}

try {
    # Récupérer la liste des workflows
    Write-Host "📡 Récupération de la liste des workflows..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "$N8nHost/api/v1/workflows" -Headers $headers -Method Get
    
    $workflows = $response.data
    $count = $workflows.Count
    
    if ($count -eq 0) {
        Write-Host "⚠️  Aucun workflow trouvé" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "✅ Trouvé $count workflow(s)" -ForegroundColor Green
    Write-Host ""
    
    # Exporter chaque workflow
    $exported = 0
    foreach ($workflow in $workflows) {
        $workflowId = $workflow.id
        $workflowName = $workflow.name
        
        # Nettoyer le nom pour le système de fichiers
        $safeName = $workflowName -replace '[\\/:*?"<>|]', '_'
        $safeName = $safeName -replace '\s+', '-'
        $safeName = $safeName.ToLower()
        
        # Numéroter automatiquement
        $number = ($exported + 1).ToString("000")
        $filename = "$EXPORT_DIR/$number-$safeName.json"
        
        Write-Host "  📄 Export: $workflowName" -ForegroundColor White -NoNewline
        
        try {
            # Récupérer le workflow complet
            $fullWorkflow = Invoke-RestMethod -Uri "$N8nHost/api/v1/workflows/$workflowId" -Headers $headers -Method Get
            
            # Supprimer les données sensibles si nécessaire
            $workflowData = $fullWorkflow.data
            
            # Ajouter des métadonnées
            $export = @{
                workflow = $workflowData
                metadata = @{
                    exportedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                    exportedBy = "export-workflows.ps1"
                    environment = $Environment
                    n8nVersion = "latest"
                }
            }
            
            # Sauvegarder dans un fichier avec indentation
            $export | ConvertTo-Json -Depth 100 | Set-Content -Path $filename -Encoding UTF8
            
            Write-Host " ✅" -ForegroundColor Green
            $exported++
            
        } catch {
            Write-Host " ❌" -ForegroundColor Red
            Write-Host "    Erreur: $_" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "✅ Export terminé avec succès!" -ForegroundColor Green
    Write-Host "📊 $exported/$count workflow(s) exporté(s)" -ForegroundColor Cyan
    Write-Host "📁 Fichiers sauvegardés dans: $EXPORT_DIR" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Prochaines étapes:" -ForegroundColor Cyan
    Write-Host "   1. Vérifiez les fichiers exportés" -ForegroundColor Gray
    Write-Host "   2. Commitez les changements:" -ForegroundColor Gray
    Write-Host "      git add workflows/" -ForegroundColor White
    Write-Host "      git commit -m 'chore: Export n8n workflows'" -ForegroundColor White
    Write-Host "      git push" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "❌ Erreur lors de l'export: $_" -ForegroundColor Red
    
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "   Vérifiez vos credentials N8N_BASIC_AUTH_USER et N8N_BASIC_AUTH_PASSWORD" -ForegroundColor Yellow
    }
    
    exit 1
}
