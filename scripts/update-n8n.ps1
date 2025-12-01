# Script de mise à jour n8n avec sauvegarde automatique
# Ce script exporte les workflows, sauvegarde les volumes, puis met à jour n8n

param(
    [switch]$SkipBackup = $false,
    [switch]$SkipWorkflowExport = $false
)

Write-Host "🚀 Mise à jour de n8n" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que Docker est accessible
try {
    $null = docker --version
} catch {
    Write-Host "❌ Erreur: Docker n'est pas accessible" -ForegroundColor Red
    Write-Host "   Assurez-vous que Docker Desktop est démarré" -ForegroundColor Yellow
    exit 1
}

# 1. Exporter les workflows (sauf si --SkipWorkflowExport)
if (-not $SkipWorkflowExport) {
    Write-Host "📤 Étape 1/5 : Export des workflows..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\export-workflows.ps1"
        Write-Host "✅ Workflows exportés" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Impossible d'exporter les workflows (n8n non démarré ?)" -ForegroundColor Yellow
        Write-Host "   Continuation de la mise à jour..." -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "⏭️  Étape 1/5 : Export des workflows ignoré" -ForegroundColor Gray
    Write-Host ""
}

# 2. Créer un backup des volumes (sauf si --SkipBackup)
if (-not $SkipBackup) {
    Write-Host "💾 Étape 2/5 : Sauvegarde des volumes Docker..." -ForegroundColor Cyan
    
    $backupDir = "backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Write-Host "   📁 Dossier de backup: $backupDir" -ForegroundColor Gray
    
    # Récupérer le nom du projet depuis .env
    $projectName = "upsylon-n8n-secured"
    if (Test-Path ".env") {
        $envContent = Get-Content .env
        foreach ($line in $envContent) {
            if ($line -match '^PROJECT_NAME=(.+)$') {
                $projectName = $matches[1]
                break
            }
        }
    }
    
    Write-Host "   💾 Sauvegarde de n8n_data..." -ForegroundColor Gray
    docker run --rm `
        -v "${projectName}_n8n_data:/data" `
        -v "${PWD}/${backupDir}:/backup" `
        alpine tar czf /backup/n8n_data.tar.gz -C /data . 2>$null
    
    Write-Host "   💾 Sauvegarde de postgres_data..." -ForegroundColor Gray
    docker run --rm `
        -v "${projectName}_postgres_data:/data" `
        -v "${PWD}/${backupDir}:/backup" `
        alpine tar czf /backup/postgres_data.tar.gz -C /data . 2>$null
    
    Write-Host "✅ Backup créé dans $backupDir" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "⏭️  Étape 2/5 : Sauvegarde ignorée" -ForegroundColor Gray
    Write-Host ""
}

# 3. Télécharger la nouvelle version
Write-Host "📥 Étape 3/5 : Téléchargement de la nouvelle version..." -ForegroundColor Cyan
try {
    docker compose pull
    Write-Host "✅ Nouvelle version téléchargée" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors du téléchargement" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 4. Redémarrer avec la nouvelle version
Write-Host "🔄 Étape 4/5 : Redémarrage avec la nouvelle version..." -ForegroundColor Cyan
try {
    docker compose up -d
    Write-Host "✅ Conteneurs redémarrés" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors du redémarrage" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 5. Vérifier que tout fonctionne
Write-Host "🔍 Étape 5/5 : Vérification..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$status = docker compose ps --format json | ConvertFrom-Json
$allHealthy = $true

foreach ($service in $status) {
    $serviceName = $service.Service
    $serviceState = $service.State
    
    if ($serviceState -eq "running") {
        Write-Host "   ✅ $serviceName : running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $serviceName : $serviceState" -ForegroundColor Red
        $allHealthy = $false
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan

if ($allHealthy) {
    Write-Host "✅ Mise à jour terminée avec succès!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Prochaines étapes:" -ForegroundColor Cyan
    Write-Host "   1. Vérifiez l'interface web" -ForegroundColor Gray
    Write-Host "   2. Testez vos workflows" -ForegroundColor Gray
    Write-Host "   3. Vérifiez les logs si nécessaire:" -ForegroundColor Gray
    Write-Host "      docker compose logs -f n8n" -ForegroundColor White
    
    if (-not $SkipWorkflowExport) {
        Write-Host ""
        Write-Host "💡 N'oubliez pas de commiter les workflows exportés:" -ForegroundColor Cyan
        Write-Host "   git add workflows/" -ForegroundColor White
        Write-Host "   git commit -m 'chore: Backup workflows before update'" -ForegroundColor White
        Write-Host "   git push" -ForegroundColor White
    }
} else {
    Write-Host "⚠️  Certains services ne sont pas démarrés correctement" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔍 Vérifiez les logs:" -ForegroundColor Cyan
    Write-Host "   docker compose logs -f" -ForegroundColor White
}

Write-Host ""
