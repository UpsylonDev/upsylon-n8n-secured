# Guide de Versionnement des Workflows n8n

## 🎯 Objectif

Sauvegarder et versionner vos workflows n8n dans Git pour :

- ✅ Tracer l'historique des modifications
- ✅ Collaborer avec d'autres développeurs
- ✅ Restaurer facilement en cas de problème
- ✅ Déployer sur différents environnements

## 📋 Méthodes de Versionnement

### Méthode 1 : Export Manuel (Recommandé pour débuter)

#### Export d'un workflow

1. Dans l'interface n8n, ouvrez votre workflow
2. Cliquez sur le menu `...` (trois points) en haut à droite
3. Sélectionnez **"Download"**
4. Sauvegardez le fichier JSON dans le dossier `workflows/`

#### Structure recommandée

```
upsylon-n8n-secured/
├── workflows/
│   ├── production/
│   │   ├── email-automation.json
│   │   ├── data-sync.json
│   │   └── webhook-handler.json
│   ├── staging/
│   │   └── test-workflow.json
│   └── README.md
├── docker-compose.yml
└── .env
```

#### Import d'un workflow

1. Dans n8n, cliquez sur le bouton **"+"** pour créer un nouveau workflow
2. Cliquez sur le menu `...` (trois points)
3. Sélectionnez **"Import from File"**
4. Choisissez votre fichier JSON

### Méthode 2 : Export Automatique via Script

Créez un script pour exporter automatiquement tous vos workflows.

#### Script PowerShell : `export-workflows.ps1`

```powershell
# Configuration
$N8N_HOST = "http://localhost:3000"
$N8N_USER = $env:N8N_BASIC_AUTH_USER
$N8N_PASSWORD = $env:N8N_BASIC_AUTH_PASSWORD
$EXPORT_DIR = "./workflows/production"

# Créer le dossier s'il n'existe pas
New-Item -ItemType Directory -Force -Path $EXPORT_DIR | Out-Null

# Créer les credentials en base64
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${N8N_USER}:${N8N_PASSWORD}"))

# Récupérer la liste des workflows
$headers = @{
    "Authorization" = "Basic $credentials"
}

try {
    $workflows = Invoke-RestMethod -Uri "$N8N_HOST/api/v1/workflows" -Headers $headers -Method Get

    Write-Host "✅ Trouvé $($workflows.data.Count) workflow(s)" -ForegroundColor Green

    # Exporter chaque workflow
    foreach ($workflow in $workflows.data) {
        $workflowId = $workflow.id
        $workflowName = $workflow.name -replace '[\\/:*?"<>|]', '_'
        $filename = "$EXPORT_DIR/$workflowName.json"

        # Récupérer le workflow complet
        $fullWorkflow = Invoke-RestMethod -Uri "$N8N_HOST/api/v1/workflows/$workflowId" -Headers $headers -Method Get

        # Sauvegarder dans un fichier
        $fullWorkflow.data | ConvertTo-Json -Depth 100 | Set-Content -Path $filename -Encoding UTF8

        Write-Host "  📄 Exporté: $workflowName" -ForegroundColor Cyan
    }

    Write-Host "`n✅ Export terminé avec succès!" -ForegroundColor Green
    Write-Host "📁 Fichiers sauvegardés dans: $EXPORT_DIR" -ForegroundColor Yellow

} catch {
    Write-Host "❌ Erreur lors de l'export: $_" -ForegroundColor Red
    exit 1
}
```

#### Utilisation du script

```powershell
# Charger les variables d'environnement
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Exécuter l'export
.\export-workflows.ps1

# Commiter les changements
git add workflows/
git commit -m "chore: Export n8n workflows"
git push
```

### Méthode 3 : Utiliser le Node Git de n8n (Avancé)

n8n possède un node **Git** intégré qui permet de :

- Commiter automatiquement les workflows
- Pousser vers un repository Git
- Créer des branches
- Gérer les pull requests

#### Configuration

1. Dans n8n, créez un nouveau workflow "Workflow Backup"
2. Ajoutez un trigger **Cron** (ex: tous les jours à minuit)
3. Ajoutez un node **HTTP Request** pour récupérer tous les workflows via l'API
4. Ajoutez un node **Git** pour commiter les changements
5. Configurez les credentials Git

### Méthode 4 : Backup Automatique avec Docker

Créez un conteneur qui exporte régulièrement vos workflows.

#### Ajout au `docker-compose.yml`

```yaml
n8n-backup:
  image: alpine:latest
  container_name: ${PROJECT_NAME:-n8n-secure}-backup
  volumes:
    - ./workflows:/backup
    - n8n_data:/n8n-data:ro
  command: >
    sh -c "
      apk add --no-cache curl jq &&
      while true; do
        echo 'Backup scheduled...' &&
        sleep 86400
      done
    "
  depends_on:
    - n8n
```

## 🔄 Workflow Recommandé

### Pour le développement

1. **Créer/Modifier** un workflow dans n8n
2. **Tester** le workflow
3. **Exporter** le workflow (manuellement ou via script)
4. **Commiter** dans Git
   ```powershell
   git add workflows/
   git commit -m "feat: Add email automation workflow"
   git push
   ```

### Pour le déploiement

1. **Cloner** le repository
2. **Configurer** `.env`
3. **Démarrer** Docker Compose
   ```powershell
   docker compose up -d
   ```
4. **Importer** les workflows depuis `workflows/production/`

## 📁 Structure de Fichiers Recommandée

```
upsylon-n8n-secured/
├── .github/
│   └── workflows/
│       └── backup-n8n-workflows.yml  # CI/CD pour backup auto
├── workflows/
│   ├── production/
│   │   ├── 001-email-automation.json
│   │   ├── 002-data-sync.json
│   │   └── 003-webhook-handler.json
│   ├── staging/
│   │   └── test-workflow.json
│   ├── templates/
│   │   └── base-workflow-template.json
│   └── README.md                      # Documentation des workflows
├── scripts/
│   ├── export-workflows.ps1           # Script d'export
│   └── import-workflows.ps1           # Script d'import
├── docker-compose.yml
├── .env.example
├── .gitignore
├── TROUBLESHOOTING.md
└── WORKFLOWS_VERSIONING.md
```

## 🛡️ Bonnes Pratiques

### Sécurité

⚠️ **ATTENTION** : Les workflows exportés peuvent contenir des **données sensibles** !

- ❌ **Ne commitez JAMAIS** les credentials dans les workflows
- ✅ Utilisez des **variables d'environnement** dans n8n
- ✅ Configurez n8n pour **ne pas exporter les credentials**
  ```env
  N8N_EXPORT_CREDENTIALS=false
  ```
- ✅ Vérifiez chaque fichier JSON avant de commiter

### Nommage

- Utilisez des noms descriptifs : `email-automation.json` au lieu de `workflow-1.json`
- Préfixez avec un numéro pour l'ordre : `001-init.json`, `002-process.json`
- Utilisez des slugs : `data-sync-salesforce.json`

### Documentation

Créez un `workflows/README.md` pour documenter :

- Le but de chaque workflow
- Les dépendances entre workflows
- Les variables d'environnement requises
- Les credentials nécessaires

### Versioning

```powershell
# Commits sémantiques
git commit -m "feat(workflow): Add Salesforce integration"
git commit -m "fix(workflow): Correct email template"
git commit -m "chore(workflow): Update webhook URL"
```

## 🚀 Automatisation avec GitHub Actions

Créez `.github/workflows/backup-n8n-workflows.yml` :

```yaml
name: Backup n8n Workflows

on:
  schedule:
    - cron: "0 2 * * *" # Tous les jours à 2h du matin
  workflow_dispatch: # Permet le déclenchement manuel

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Export workflows
        env:
          N8N_HOST: ${{ secrets.N8N_HOST }}
          N8N_USER: ${{ secrets.N8N_USER }}
          N8N_PASSWORD: ${{ secrets.N8N_PASSWORD }}
        run: |
          # Script d'export ici

      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add workflows/
          git diff --quiet && git diff --staged --quiet || git commit -m "chore: Auto-backup workflows [skip ci]"
          git push
```

## 📊 Comparaison des Méthodes

| Méthode           | Complexité    | Automatisation | Recommandé pour           |
| ----------------- | ------------- | -------------- | ------------------------- |
| Export Manuel     | ⭐ Facile     | ❌ Non         | Débutants, petits projets |
| Script PowerShell | ⭐⭐ Moyen    | ✅ Oui         | Projets moyens            |
| Node Git n8n      | ⭐⭐⭐ Avancé | ✅ Oui         | Experts n8n               |
| GitHub Actions    | ⭐⭐⭐ Avancé | ✅ Oui         | Production, équipes       |

## 🆘 Dépannage

### Les workflows exportés ne s'importent pas

- Vérifiez la version de n8n (compatibilité)
- Vérifiez que les nodes utilisés sont installés
- Vérifiez les credentials manquants

### Les credentials sont exposés dans Git

```powershell
# Supprimer un fichier de l'historique Git
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch workflows/production/sensitive-workflow.json" \
  --prune-empty --tag-name-filter cat -- --all
```

### Conflit entre versions de workflows

- Utilisez des branches Git pour tester
- Documentez les changements dans les commits
- Utilisez des tags Git pour les versions stables
