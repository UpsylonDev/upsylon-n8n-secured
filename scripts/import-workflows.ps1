# Import n8n Workflows Script
# Ce script importe tous les workflows depuis le dossier workflows/ vers n8n

param(
    [string]$Environment = "production",
    [string]$N8nHost = "http://localhost:3000",
    [switch]$Force = $false
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
$IMPORT_DIR = "./workflows/$Environment"

Write-Host "🚀 Import des workflows n8n" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Host: $N8nHost" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host "Import dir: $IMPORT_DIR" -ForegroundColor Gray
Write-Host "Force: $Force" -ForegroundColor Gray
Write-Host ""

# Vérifier que le dossier existe
if (-not (Test-Path $IMPORT_DIR)) {
    Write-Host "❌ Erreur: Le dossier $IMPORT_DIR n'existe pas" -ForegroundColor Red
    exit 1
}

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

# Créer les credentials en base64
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${N8N_USER}:${N8N_PASSWORD}"))

# Headers pour l'API
$headers = @{
    "Authorization" = "Basic $credentials"
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

# Récupérer la liste des fichiers JSON
$workflowFiles = Get-ChildItem -Path $IMPORT_DIR -Filter "*.json" -File | Sort-Object Name

if ($workflowFiles.Count -eq 0) {
    Write-Host "⚠️  Aucun workflow trouvé dans $IMPORT_DIR" -ForegroundColor Yellow
    exit 0
}

Write-Host "📁 Trouvé $($workflowFiles.Count) fichier(s) de workflow" -ForegroundColor Green
Write-Host ""

# Récupérer les workflows existants
try {
    $response = Invoke-RestMethod -Uri "$N8nHost/api/v1/workflows" -Headers $headers -Method Get
    $existingWorkflows = @{}
    foreach ($wf in $response.data) {
        $existingWorkflows[$wf.name] = $wf.id
    }
} catch {
    Write-Host "❌ Erreur lors de la récupération des workflows existants: $_" -ForegroundColor Red
    exit 1
}

# Importer chaque workflow
$imported = 0
$updated = 0
$skipped = 0
$errors = 0

foreach ($file in $workflowFiles) {
    Write-Host "  📄 Import: $($file.Name)" -ForegroundColor White -NoNewline
    
    try {
        # Lire le fichier JSON
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $data = $content | ConvertFrom-Json
        
        # Extraire le workflow (gérer les deux formats)
        if ($data.workflow) {
            $workflow = $data.workflow
        } else {
            $workflow = $data
        }
        
        $workflowName = $workflow.name
        
        # Vérifier si le workflow existe déjà
        if ($existingWorkflows.ContainsKey($workflowName)) {
            if ($Force) {
                # Mettre à jour le workflow existant
                $workflowId = $existingWorkflows[$workflowName]
                $body = $workflow | ConvertTo-Json -Depth 100
                
                $null = Invoke-RestMethod `
                    -Uri "$N8nHost/api/v1/workflows/$workflowId" `
                    -Headers $headers `
                    -Method Patch `
                    -Body $body
                
                Write-Host " ✅ (mis à jour)" -ForegroundColor Yellow
                $updated++
            } else {
                Write-Host " ⏭️  (déjà existant, utilisez -Force pour mettre à jour)" -ForegroundColor Gray
                $skipped++
            }
        } else {
            # Créer un nouveau workflow
            # Supprimer l'ID s'il existe (pour éviter les conflits)
            $workflow.PSObject.Properties.Remove('id')
            
            $body = $workflow | ConvertTo-Json -Depth 100
            
            $null = Invoke-RestMethod `
                -Uri "$N8nHost/api/v1/workflows" `
                -Headers $headers `
                -Method Post `
                -Body $body
            
            Write-Host " ✅ (nouveau)" -ForegroundColor Green
            $imported++
        }
        
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "    Erreur: $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ Import terminé!" -ForegroundColor Green
Write-Host "📊 Statistiques:" -ForegroundColor Cyan
Write-Host "   - Nouveaux: $imported" -ForegroundColor Green
Write-Host "   - Mis à jour: $updated" -ForegroundColor Yellow
Write-Host "   - Ignorés: $skipped" -ForegroundColor Gray
Write-Host "   - Erreurs: $errors" -ForegroundColor Red
Write-Host ""

if ($skipped -gt 0 -and -not $Force) {
    Write-Host "💡 Astuce: Utilisez -Force pour mettre à jour les workflows existants" -ForegroundColor Cyan
    Write-Host "   .\scripts\import-workflows.ps1 -Force" -ForegroundColor White
}
