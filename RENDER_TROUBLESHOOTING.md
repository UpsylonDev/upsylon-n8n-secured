# Guide de Dépannage Render.io - Page /setup

## 🔴 Problème : Redirection vers /setup à chaque déploiement

### Symptômes

- Vous arrivez toujours sur la page `/setup` après un déploiement
- Vos workflows disparaissent
- Vous devez reconfigurer n8n à chaque fois

### Causes possibles

#### 1. ❌ Disques Render non persistants (CAUSE PRINCIPALE)

Sur Render.io, les disques peuvent être **réinitialisés** dans certains cas :

- Changement de plan (Free → Starter, etc.)
- Changement de région
- Suppression et recréation du service
- Certaines mises à jour du `render.yaml`

#### 2. ❌ Variables d'environnement incorrectes

Si `DB_POSTGRESDB_PASSWORD` change entre les déploiements, PostgreSQL ne peut plus accéder à la base de données existante.

#### 3. ❌ Références de service incorrectes

Dans `render.yaml`, les références `fromService` doivent pointer vers le bon nom de service.

---

## ✅ Solutions

### Solution 1 : Utiliser Render Managed PostgreSQL (RECOMMANDÉ)

Au lieu d'utiliser un service privé PostgreSQL avec disque, utilisez la **base de données managée** de Render :

#### Étapes

1. **Supprimer le service PostgreSQL privé** de `render.yaml`
2. **Créer une base PostgreSQL managée** sur Render :

   - Dashboard Render → New → PostgreSQL
   - Nom : `n8n-postgres`
   - Plan : Free (ou Starter pour production)
   - Créer

3. **Mettre à jour `render.yaml`** :

```yaml
services:
  - type: web
    name: n8n-secured
    runtime: docker
    plan: starter
    envVars:
      - key: N8N_BASIC_AUTH_ACTIVE
        value: "true"
      - key: N8N_BASIC_AUTH_USER
        value: admin
      - key: N8N_BASIC_AUTH_PASSWORD
        generateValue: true
      - key: N8N_HOST
        fromService:
          type: web
          name: n8n-secured
          property: host
      - key: N8N_PORT
        value: "5678"
      - key: N8N_PROTOCOL
        value: https
      - key: NODE_ENV
        value: production
      - key: WEBHOOK_URL
        fromService:
          type: web
          name: n8n-secured
          property: url
      # Configuration PostgreSQL Managée
      - key: DB_TYPE
        value: postgresdb
      - key: DB_POSTGRESDB_DATABASE
        fromDatabase:
          name: n8n-postgres
          property: database
      - key: DB_POSTGRESDB_HOST
        fromDatabase:
          name: n8n-postgres
          property: host
      - key: DB_POSTGRESDB_PORT
        fromDatabase:
          name: n8n-postgres
          property: port
      - key: DB_POSTGRESDB_USER
        fromDatabase:
          name: n8n-postgres
          property: user
      - key: DB_POSTGRESDB_PASSWORD
        fromDatabase:
          name: n8n-postgres
          property: password
      - key: N8N_RUNNERS_ENABLED
        value: "true"
      - key: N8N_BLOCK_ENV_ACCESS_IN_NODE
        value: "false"
      - key: N8N_GIT_NODE_DISABLE_BARE_REPOS
        value: "true"
    disk:
      name: n8n_data
      mountPath: /home/node/.n8n
      sizeGB: 1

databases:
  - name: n8n-postgres
    plan: starter # ou 'free' pour tester
    databaseName: n8n
    user: n8n
```

#### Avantages de PostgreSQL Managée

- ✅ **Backups automatiques** quotidiens
- ✅ **Haute disponibilité**
- ✅ **Pas de perte de données** lors des redéploiements
- ✅ **Monitoring inclus**
- ✅ **Mises à jour automatiques**

---

### Solution 2 : Vérifier la persistance du disque n8n_data

Si vous gardez PostgreSQL en service privé, assurez-vous que les disques persistent :

#### Vérifications

1. **Dans le Dashboard Render** :

   - Allez dans votre service `n8n-secured`
   - Onglet **"Disks"**
   - Vérifiez que `n8n_data` est bien monté sur `/home/node/.n8n`
   - Vérifiez la taille utilisée

2. **Dans le service PostgreSQL** :
   - Allez dans votre service `postgres`
   - Onglet **"Disks"**
   - Vérifiez que `postgres_data` est bien monté sur `/var/lib/postgresql/data`
   - Vérifiez la taille utilisée

#### Si les disques sont vides après redéploiement

Cela signifie que Render a recréé les disques. **Causes possibles** :

- Changement de `mountPath` dans `render.yaml`
- Changement de `name` du disque
- Suppression manuelle du disque
- Migration de service

---

### Solution 3 : Utiliser des variables d'environnement fixes

Au lieu de `generateValue: true` pour les mots de passe, utilisez des **valeurs fixes** :

#### Dans le Dashboard Render

1. Allez dans votre service `n8n-secured`
2. Onglet **"Environment"**
3. Trouvez `N8N_BASIC_AUTH_PASSWORD`
4. **Copiez la valeur générée** (important !)
5. Modifiez pour mettre une valeur fixe

#### Dans `render.yaml`

```yaml
envVars:
  - key: N8N_BASIC_AUTH_PASSWORD
    sync: false # Ne pas régénérer à chaque déploiement
```

Ou mieux, utilisez un **Environment Group** :

1. Dashboard Render → Environment Groups → New
2. Nom : `n8n-secrets`
3. Ajoutez :
   - `N8N_BASIC_AUTH_PASSWORD` = votre mot de passe
   - `POSTGRES_PASSWORD` = votre mot de passe PostgreSQL
4. Liez ce groupe à votre service

---

### Solution 4 : Sauvegarder et restaurer les workflows

Si vous avez déjà perdu vos workflows, vous pouvez les restaurer depuis Git :

#### Depuis votre machine locale

```powershell
# 1. Assurez-vous que vos workflows sont dans Git
git pull

# 2. Vérifiez que les workflows sont présents
ls workflows/production/

# 3. Importez-les via l'API Render
# (nécessite d'avoir accès à l'URL de votre instance Render)
```

#### Script d'import vers Render

```powershell
# Configuration
$RENDER_URL = "https://votre-app.onrender.com"
$N8N_USER = "admin"
$N8N_PASSWORD = "votre-mot-de-passe"

# Importer les workflows
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${N8N_USER}:${N8N_PASSWORD}"))
$headers = @{
    "Authorization" = "Basic $credentials"
    "Content-Type" = "application/json"
}

Get-ChildItem -Path "workflows/production/*.json" | ForEach-Object {
    $workflow = Get-Content $_.FullName | ConvertFrom-Json
    $body = $workflow.workflow | ConvertTo-Json -Depth 100

    try {
        Invoke-RestMethod -Uri "$RENDER_URL/api/v1/workflows" -Headers $headers -Method Post -Body $body
        Write-Host "✅ Importé: $($_.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur: $($_.Name)" -ForegroundColor Red
    }
}
```

---

## 🔍 Diagnostic

### Vérifier si PostgreSQL conserve les données

1. **Connectez-vous à votre service PostgreSQL** via Render Shell :

   ```bash
   # Dans le Dashboard Render, service postgres, onglet "Shell"
   psql -U n8n -d n8n
   ```

2. **Vérifiez les tables** :

   ```sql
   \dt
   ```

3. **Vérifiez les workflows** :
   ```sql
   SELECT id, name, active FROM workflow_entity;
   ```

Si les tables sont vides ou n'existent pas, c'est que PostgreSQL a été réinitialisé.

### Vérifier les logs

1. **Dashboard Render** → Service `n8n-secured` → **Logs**
2. Recherchez :
   - `Database migration` (doit dire "already up to date")
   - `Owner setup required` (indique que la DB est vide)
   - Erreurs de connexion PostgreSQL

---

## 📋 Checklist de Configuration Render

### Configuration actuelle (render.yaml)

- [ ] Service `n8n-secured` avec `runtime: docker`
- [ ] Disque `n8n_data` monté sur `/home/node/.n8n`
- [ ] Variables d'environnement correctes
- [ ] Références `fromService` pointent vers `n8n-secured` (pas `n8n`)

### PostgreSQL

**Option A : Service Privé (actuel)**

- [ ] Service `postgres` avec `image: postgres:15-alpine`
- [ ] Disque `postgres_data` monté sur `/var/lib/postgresql/data`
- [ ] Variables d'environnement `POSTGRES_*` définies
- [ ] Mot de passe PostgreSQL **fixe** (pas `generateValue: true`)

**Option B : Managed Database (recommandé)**

- [ ] Base de données PostgreSQL créée dans Render
- [ ] Variables `DB_POSTGRESDB_*` utilisent `fromDatabase`
- [ ] Service privé PostgreSQL supprimé de `render.yaml`

### Sécurité

- [ ] `N8N_BASIC_AUTH_PASSWORD` défini et **fixe**
- [ ] `POSTGRES_PASSWORD` défini et **fixe**
- [ ] Credentials stockés dans un Environment Group

---

## 🚀 Migration vers PostgreSQL Managée (Recommandé)

### Étape 1 : Exporter les données actuelles

Si vous avez des workflows à sauvegarder :

```powershell
# Depuis votre machine locale
.\scripts\export-workflows.ps1 -N8nHost "https://votre-app.onrender.com"
```

### Étape 2 : Créer la base PostgreSQL managée

1. Dashboard Render → **New** → **PostgreSQL**
2. Nom : `n8n-postgres`
3. Database : `n8n`
4. User : `n8n`
5. Plan : Starter (ou Free pour tester)
6. Région : Même que votre service n8n
7. **Create Database**

### Étape 3 : Mettre à jour render.yaml

Remplacez le contenu par la configuration avec `fromDatabase` (voir Solution 1).

### Étape 4 : Redéployer

```bash
git add render.yaml
git commit -m "feat: Migrate to Render Managed PostgreSQL"
git push
```

Render va automatiquement :

1. Créer la nouvelle base de données
2. Redéployer n8n avec la nouvelle configuration
3. n8n va initialiser la base de données

### Étape 5 : Restaurer les workflows

```powershell
# Importer les workflows depuis Git
.\scripts\import-workflows.ps1 -N8nHost "https://votre-app.onrender.com" -Force
```

---

## 📊 Comparaison des Options

| Critère             | Service Privé + Disk | Managed PostgreSQL |
| ------------------- | -------------------- | ------------------ |
| **Coût**            | Inclus dans plan web | +$7/mois (Starter) |
| **Persistance**     | ⚠️ Peut être perdue  | ✅ Garantie        |
| **Backups**         | ❌ Manuel            | ✅ Automatiques    |
| **Performance**     | ⚠️ Limitée           | ✅ Optimisée       |
| **Maintenance**     | ⚠️ Manuelle          | ✅ Automatique     |
| **Recommandé pour** | Tests, dev           | Production         |

---

## 🆘 Support

Si le problème persiste :

1. **Vérifiez les logs Render** pour les erreurs PostgreSQL
2. **Contactez le support Render** si les disques ne persistent pas
3. **Utilisez PostgreSQL Managée** pour éviter les problèmes de persistance

---

## 💡 Résumé

**Problème** : Page `/setup` à chaque déploiement = Base de données vide

**Cause** : Disques Render réinitialisés ou variables d'environnement changeantes

**Solution recommandée** : Migrer vers **Render Managed PostgreSQL**

**Solution alternative** : Vérifier que les disques persistent et utiliser des mots de passe fixes
