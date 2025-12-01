# Workflows n8n

Ce dossier contient tous les workflows n8n versionnés pour ce projet.

## 📁 Structure

- **`production/`** : Workflows actifs en production
- **`staging/`** : Workflows en test
- **`templates/`** : Templates réutilisables

## 📝 Convention de Nommage

Format : `XXX-nom-descriptif.json`

- `XXX` : Numéro d'ordre (001, 002, etc.)
- `nom-descriptif` : Description en kebab-case

Exemples :

- `001-email-automation.json`
- `002-data-sync-salesforce.json`
- `003-webhook-handler.json`

## 🔄 Workflow de Développement

### 1. Créer un nouveau workflow

1. Créez le workflow dans l'interface n8n
2. Testez-le en staging
3. Exportez-le : Menu `...` → `Download`
4. Sauvegardez dans `workflows/staging/`
5. Commitez :
   ```powershell
   git add workflows/staging/
   git commit -m "feat(workflow): Add new data sync workflow"
   ```

### 2. Promouvoir en production

1. Testez le workflow en staging
2. Déplacez le fichier vers `workflows/production/`
3. Renommez avec le bon numéro d'ordre
4. Commitez :
   ```powershell
   git add workflows/
   git commit -m "feat(workflow): Promote data sync to production"
   ```

### 3. Modifier un workflow existant

1. Modifiez le workflow dans n8n
2. Testez les changements
3. Exportez et remplacez le fichier existant
4. Commitez avec un message descriptif :
   ```powershell
   git add workflows/production/002-data-sync.json
   git commit -m "fix(workflow): Correct email template formatting"
   ```

## 🚀 Scripts Disponibles

### Export automatique

```powershell
# Exporter tous les workflows actifs
.\scripts\export-workflows.ps1
```

### Import automatique

```powershell
# Importer tous les workflows depuis production
.\scripts\import-workflows.ps1 -Environment production
```

## ⚠️ Sécurité

**IMPORTANT** : Les workflows ne doivent PAS contenir de credentials en dur !

- ✅ Utilisez les **Environment Variables** de n8n
- ✅ Configurez `N8N_EXPORT_CREDENTIALS=false` dans `.env`
- ✅ Vérifiez chaque fichier JSON avant de commiter

### Vérification avant commit

```powershell
# Rechercher des mots-clés sensibles
Select-String -Path workflows/**/*.json -Pattern "password|secret|token|api_key" -CaseSensitive
```

## 📊 Workflows Actuels

| Fichier | Description              | Status | Dernière MAJ |
| ------- | ------------------------ | ------ | ------------ |
| -       | Aucun workflow versionné | -      | -            |

> 💡 **Astuce** : Mettez à jour ce tableau à chaque ajout/modification de workflow

## 🔗 Ressources

- [Documentation n8n](https://docs.n8n.io/)
- [Guide de versionnement](../WORKFLOWS_VERSIONING.md)
- [API n8n](https://docs.n8n.io/api/)
